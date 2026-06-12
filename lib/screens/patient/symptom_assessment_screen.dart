import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/speech_input_service.dart';
import '../../services/symptom_extraction_service.dart';
import '../../services/triage_service.dart';
import '../../services/encryption_service.dart';
import 'symptom_result_screen.dart';
import '../../utils/stage1_input_builder.dart';

// English keys are kept as-is — these are sent to the AI API unchanged
const Set<String> _triageRelevantSymptoms = {
  'Chest pain',
  'Shortness of breath',
  'Trouble breathing',
  'Abdominal pain',
  'Headache',
  'Seizures',
  'Dizziness',
  'Fever',
  'Confusion',
  'Weakness',
  'Vomiting',
  'Persistent vomiting',
  'Coughing blood',
  'Fracture',
  'Back pain',
  'Radiating jaw pain',
  'Heart palpitations',
};

const Map<String, String> _categoryAr = {
  "Chest & Heart": "الصدر والقلب",
  "Head & Neurological": "الرأس والأعصاب",
  "Breathing & Respiratory": "التنفس والجهاز التنفسي",
  "Abdomen & Digestive": "البطن والجهاز الهضمي",
  "General Symptoms": "الأعراض العامة",
  "Muscles & Joints": "العضلات والمفاصل",
  "Mental Health": "الصحة النفسية",
};

const Map<String, String> _symptomAr = {
  "Chest pain": "ألم في الصدر",
  "Chest tightness": "ضيق في الصدر",
  "Shortness of breath": "ضيق في التنفس",
  "Heart palpitations": "خفقان القلب",
  "Radiating jaw pain": "ألم يمتد للفك",
  "Headache": "صداع",
  "Seizures": "نوبات تشنجية",
  "Dizziness": "دوخة",
  "Vision changes": "تغيرات في الرؤية",
  "Confusion": "ارتباك",
  "Weakness": "ضعف",
  "Numbness": "تخدر",
  "Wheezing": "صفير في التنفس",
  "Coughing blood": "سعال بالدم",
  "Persistent cough": "سعال مستمر",
  "Sore throat": "التهاب الحلق",
  "Trouble breathing": "صعوبة في التنفس",
  "Abdominal pain": "ألم في البطن",
  "Vomiting": "قيء",
  "Persistent vomiting": "قيء مستمر",
  "Diarrhea": "إسهال",
  "Blood in stool": "دم في البراز",
  "Bloating": "انتفاخ",
  "Fever": "حمى",
  "Fatigue": "إرهاق",
  "Body aches": "آلام جسدية",
  "Weight loss": "فقدان الوزن",
  "Fracture": "كسر",
  "Joint swelling": "تورم المفاصل",
  "Muscle spasms": "تشنج عضلي",
  "Back pain": "ألم الظهر",
  "Anxiety": "قلق",
  "Depressed mood": "مزاج مكتئب",
  "Memory issues": "مشاكل في الذاكرة",
};

class SymptomAssessmentScreen extends StatefulWidget {
  const SymptomAssessmentScreen({
    super.key,
    this.speechService,
    this.extractionService,
    this.predictStage1,
    @visibleForTesting this.profileOverride,
  });

  /// Test seams — production uses the real services when these are null.
  final SpeechInputService? speechService;
  final SymptomExtractionService? extractionService;
  final Future<TriageResult> Function(Stage1Request request)? predictStage1;

  /// Skips the Firestore profile fetch in widget tests.
  final ({String name, int age, int sex})? profileOverride;

  @override
  State<SymptomAssessmentScreen> createState() =>
      _SymptomAssessmentScreenState();
}

class _SymptomAssessmentScreenState extends State<SymptomAssessmentScreen> {
  final Set<String> _selectedSymptoms = {};
  final TextEditingController _descriptionController = TextEditingController();

  double _nrsPain = 0.0;
  int _arrivalMode = 1;
  int _injury = 2;
  int _mental = 1;

  String? _patientName;
  int? _age;
  int? _sex;
  bool _isLoading = false;

  // ── Voice & NLP-assisted entry (addendum §4.14) ──────────────────────────
  late final SpeechInputService _speech;
  late final SymptomExtractionService _extractor;

  bool _isListening = false;
  bool _voiceUsed = false;
  bool _transcriptEdited = false;
  String? _sttLocaleId;
  String? _dictationLangOverride;
  String _textBeforeListening = '';

  bool _isExtracting = false;
  ExtractedSymptoms? _pendingSuggestions;
  Map<String, dynamic>? _nlpExtractedRaw;
  bool _suggestionsApplied = false;

  /// Canonical English complaint from extraction (FR-NLP-05); cleared when
  /// the patient manually edits the description afterwards.
  String? _chiefComplaintEn;

  final Map<String, List<String>> _symptomCategories = {
    "Chest & Heart": [
      "Chest pain",
      "Chest tightness",
      "Shortness of breath",
      "Heart palpitations",
      "Radiating jaw pain",
    ],
    "Breathing & Respiratory": [
      "Wheezing",
      "Coughing blood",
      "Persistent cough",
      "Sore throat",
      "Trouble breathing",
    ],
    "Head & Neurological": [
      "Headache",
      "Seizures",
      "Dizziness",
      "Vision changes",
      "Confusion",
      "Weakness",
      "Numbness",
    ],
    "Abdomen & Digestive": [
      "Abdominal pain",
      "Vomiting",
      "Persistent vomiting",
      "Diarrhea",
      "Blood in stool",
      "Bloating",
    ],
    "Muscles & Joints": [
      "Fracture",
      "Joint swelling",
      "Muscle spasms",
      "Back pain",
    ],
    "General Symptoms": [
      "Fever",
      "Fatigue",
      "Body aches",
      "Weakness",
      "Weight loss",
    ],
    "Mental Health": [
      "Anxiety",
      "Depressed mood",
      "Confusion",
      "Memory issues",
    ],
  };

  final Map<String, IconData> _categoryIcons = {
    "Chest & Heart": Icons.favorite_border,
    "Head & Neurological": Icons.psychology_outlined,
    "Breathing & Respiratory": Icons.air,
    "Abdomen & Digestive": Icons.restaurant_menu,
    "General Symptoms": Icons.medical_services_outlined,
    "Muscles & Joints": Icons.accessibility_new,
    "Mental Health": Icons.self_improvement,
  };

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _speech = widget.speechService ?? SpeechInputService();
    _extractor = widget.extractionService ?? SymptomExtractionService();

    final profile = widget.profileOverride;
    if (profile != null) {
      _patientName = profile.name;
      _age = profile.age;
      _sex = profile.sex;
    } else {
      _fetchProfile();
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Decrypt dob and gender via Cloud Function (they are AES-256 encrypted)
      final data = await EncryptionService.getDecryptedData(
        collection: 'users',
        docId: uid,
        fields: ['dob', 'gender'],
      );

      if (mounted) {
        setState(() {
          _patientName = data['name'] as String?;

          final dob = data['dob'] as String?;
          final gender = data['gender'] as String?;

          if (dob != null) _age = TriageService.ageFromDob(dob);
          if (gender != null) _sex = TriageService.sexFromGender(gender);
        });
      }
    } catch (_) {
      // Profile prefill is optional — on any read failure the patient simply
      // fills age/sex manually; the assessment still works.
    }
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Color get _painColor {
    if (_nrsPain <= 3) return Colors.green;
    if (_nrsPain <= 6) return Colors.orange;
    return Colors.red;
  }

  /// Language used for dictation; defaults to the active app locale and can
  /// be switched by the patient (FR-VOICE-02).
  String get _dictationLang => _dictationLangOverride ?? (_isArabic ? 'ar' : 'en');

  /// How the description was produced, for `queue.inputMethod`.
  String get _inputMethod {
    if (!_voiceUsed) return 'text';
    return _transcriptEdited ? 'voice+edited' : 'voice';
  }

  Future<void> _toggleListening() async {
    final isArabic = _isArabic;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // Permission is requested at point of use (FR-VOICE-04).
    final ready = await _speech.init(onStatus: _onSpeechStatus);
    if (!mounted) return;

    if (!ready) {
      // Typed entry stays fully functional as the fallback (FR-VOICE-05).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "الإدخال الصوتي غير متاح — يمكنك كتابة الأعراض بدلاً من ذلك."
                : "Voice input isn't available — you can type your symptoms instead.",
          ),
        ),
      );
      return;
    }

    final localeId = await _speech.resolveLocaleId(_dictationLang);
    if (!mounted) return;

    _textBeforeListening = _descriptionController.text.trim();
    setState(() {
      _isListening = true;
      _sttLocaleId = localeId ?? 'device_default';
    });

    await _speech.start(
      localeId: localeId,
      onText: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _voiceUsed = true;
          final combined = _textBeforeListening.isEmpty
              ? text
              : '$_textBeforeListening $text';
          _descriptionController.text = combined;
          _descriptionController.selection =
              TextSelection.collapsed(offset: combined.length);
          if (isFinal) _isListening = false;
        });
      },
    );
  }

  void _onSpeechStatus(String status) {
    // The recognizer auto-stops after silence; keep the mic UI in sync.
    if (!mounted) return;
    if ((status == 'notListening' || status == 'done') && _isListening) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _runExtraction() async {
    final isArabic = _isArabic;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }

    final transcript = _descriptionController.text.trim();
    if (transcript.isEmpty || _isExtracting) return;

    setState(() {
      _isExtracting = true;
      _pendingSuggestions = null;
      _suggestionsApplied = false;
    });

    final extracted = await _extractor.extract(transcript);
    if (!mounted) return;

    if (extracted == null || extracted.isEmpty) {
      // FR-NLP-06: fall back to manual entry without blocking triage.
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "تعذر تحليل الوصف — يمكنك تعبئة النموذج يدوياً."
                : "We couldn't analyze your description — you can fill the form manually.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isExtracting = false;
      _pendingSuggestions = extracted;
      _nlpExtractedRaw = extracted.toJson();
    });
  }

  /// Matches extracted keywords to the canonical English symptom chips.
  /// Unmatched keywords are never guessed at — they simply stay in the
  /// description text (FR-NLP-04).
  List<String> _matchCanonicalSymptoms(List<String> keywords) {
    final canonical = _symptomCategories.values.expand((s) => s).toSet();
    final matched = <String>[];

    for (final keyword in keywords) {
      final k = keyword.trim().toLowerCase();
      for (final symptom in canonical) {
        if (symptom.toLowerCase() == k && !matched.contains(symptom)) {
          matched.add(symptom);
        }
      }
      // Arabic transcripts may yield Arabic keywords — match those too.
      for (final entry in _symptomAr.entries) {
        if (entry.value == keyword.trim() && !matched.contains(entry.key)) {
          matched.add(entry.key);
        }
      }
    }

    return matched;
  }

  /// Moves the reviewed suggestions into the editable form fields. Nothing is
  /// submitted here — the patient still owns the submit button (FR-NLP-03).
  void _applySuggestions() {
    final extracted = _pendingSuggestions;
    if (extracted == null) return;

    setState(() {
      _selectedSymptoms.addAll(_matchCanonicalSymptoms(extracted.symptoms));

      if (extracted.nrsPain != null) {
        _nrsPain = extracted.nrsPain!.clamp(0.0, 10.0).roundToDouble();
      }
      if (extracted.injury != null) {
        _injury = extracted.injury! ? 1 : 2;
      }
      if (extracted.arrivalMode != null) {
        _arrivalMode = kArrivalModeCodes[extracted.arrivalMode] ?? _arrivalMode;
      }
      _mental = kMentalStatusCodes[extracted.mentalStatus] ?? _mental;
      _chiefComplaintEn = extracted.chiefComplaint;

      _pendingSuggestions = null;
      _suggestionsApplied = true;
    });
  }

  void _dismissSuggestions() {
    setState(() => _pendingSuggestions = null);
  }

  String _arrivalLabel(String mode, bool isArabic) {
    switch (mode) {
      case 'walk':
        return isArabic ? "مشياً" : "Walking";
      case 'ambulance':
        return isArabic ? "إسعاف" : "Ambulance";
      case 'car':
        return isArabic ? "سيارة خاصة" : "Private car";
      case 'transit':
        return isArabic ? "مواصلات عامة" : "Public transport";
      case 'referred':
        return isArabic ? "إحالة" : "Referral";
      default:
        return mode;
    }
  }

  String _mentalLabel(String status, bool isArabic) {
    switch (status) {
      case 'verbal':
        return isArabic ? "يستجيب للصوت" : "Responds to voice";
      case 'pain':
        return isArabic ? "يستجيب للألم" : "Responds to pain";
      case 'unresponsive':
        return isArabic ? "لا يستجيب" : "Unresponsive";
      default:
        return isArabic ? "يقظ" : "Alert";
    }
  }

  Future<void> _handleGetAssessment() async {
    final isArabic = _isArabic;

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
    }

    final description = _descriptionController.text.trim();

    if (_selectedSymptoms.isEmpty && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "يرجى اختيار أو وصف عرض واحد على الأقل."
                : "Please select or describe at least one symptom.",
          ),
        ),
      );
      return;
    }

    if (_age == null || _sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "تعذر تحميل ملفك الشخصي. يرجى المحاولة مرة أخرى."
                : "Could not load your profile. Please try again.",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // FR-NLP-05: the model receives the canonical English complaint when
      // one was extracted and confirmed; the raw transcript is stored as-is.
      final complaintText =
          (_chiefComplaintEn != null && _chiefComplaintEn!.trim().isNotEmpty)
              ? _chiefComplaintEn!
              : description;

      final request = buildStage1Request(
        selectedSymptoms: _selectedSymptoms.toList(),
        complaintText: complaintText,
        age: _age!,
        sex: _sex!,
        nrsPain: _nrsPain,
        mental: _mental,
        arrivalMode: _arrivalMode,
        injury: _injury,
      );

      final predict = widget.predictStage1 ?? TriageService.predictStage1;
      final result = await predict(request);

      if (!mounted) return;

      if (result.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? "تعذر الوصول إلى النموذج. تحقق من الاتصال وأعد المحاولة."
                  : "Could not reach AI model. Check connection and try again.",
            ),
          ),
        );
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Generate doc ref first so we have the ID before writing
      final ref = FirebaseFirestore.instance.collection('queue').doc();

      // Write non-sensitive operational fields directly
      await ref.set({
        'patientId': uid,
        'patientName': _patientName ?? 'Unknown',
        'queueType': 'pre_arrival',
        'status': 'pre_arrival',
        'priorityNumber': result.priorityNumber,
        'triageLevel': result.triageLevel,
        'aiPrediction': result.prediction,
        'confidence': result.confidence,
        'deferred': result.deferred,
        'probabilities': result.probabilities,
        'entropy': result.entropy,
        'stage1Inputs': request.toJson(),
        'inputMethod': _inputMethod,
        'transcript': description,
        'transcriptLocale': _voiceUsed ? _sttLocaleId : null,
        'nlpExtracted': _nlpExtractedRaw,
        'nlpConfirmed': _suggestionsApplied,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write sensitive text fields encrypted via Cloud Function
      await EncryptionService.saveSymptomData(
        docId: ref.id,
        data: {
          'patientId': uid,
          'symptoms': _selectedSymptoms.join(', '),
          'description': description,
          'chiefComplaint': complaintText,
        },
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SymptomResultScreen(
            triageResult: result,
            queueDocId: ref.id,
            selectedSymptoms: _selectedSymptoms.toList(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? "تعذر الوصول إلى النموذج. تحقق من الاتصال وأعد المحاولة."
                : "Could not reach AI model. Check connection and try again.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;

    return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            isArabic ? "تقييم الأعراض" : "Symptom Assessment",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(isArabic),
        body: _buildBody(isArabic),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildBody(bool isArabic) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(
          isArabic ? "ما هي أعراضك؟" : "What are your symptoms?",
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? "عرض مهم للفرز" : "Triage-relevant symptom",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.teal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ..._symptomCategories.entries.map(
          (e) => _buildCategoryTile(e.key, e.value, isArabic),
        ),

        const SizedBox(height: 24),

        _sectionHeader(
          isArabic
              ? "صف بكلماتك الخاصة (اختياري)"
              : "Describe in your own words (optional)",
        ),
        const SizedBox(height: 12),
        _buildVoiceDescribeSection(isArabic),
        if (_pendingSuggestions != null) ...[
          const SizedBox(height: 12),
          _buildSuggestionCard(isArabic),
        ],
        if (_suggestionsApplied) ...[
          const SizedBox(height: 12),
          _buildAppliedBanner(isArabic),
        ],

        const SizedBox(height: 24),

        _sectionHeader(
          isArabic ? "بعض التفاصيل الإضافية" : "A few more details",
        ),
        const SizedBox(height: 16),
        _sectionLabel(isArabic ? "مستوى الألم (NRS)" : "Pain Level (NRS)"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? "لا ألم" : "No pain",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _painColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isArabic
                          ? "الألم: ${_nrsPain.toInt()}/10"
                          : "Pain: ${_nrsPain.toInt()}/10",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    isArabic ? "أشد ألم" : "Worst",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              Semantics(
                label: 'Pain score, 0 is no pain, 10 is worst pain',
                child: Slider(
                  value: _nrsPain,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: _painColor,
                  onChanged: (v) => setState(() => _nrsPain = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel(isArabic ? "كيف ستصل؟" : "How will you arrive?"),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _arrivalChip(
              1,
              Icons.directions_walk,
              isArabic ? "مشياً" : "Walking",
            ),
            _arrivalChip(
              2,
              Icons.emergency,
              isArabic ? "إسعاف" : "Ambulance",
            ),
            _arrivalChip(
              3,
              Icons.directions_car,
              isArabic ? "سيارة خاصة" : "Private car",
            ),
            _arrivalChip(
              4,
              Icons.directions_bus,
              isArabic ? "مواصلات عامة" : "Public transport",
            ),
            _arrivalChip(
              5,
              Icons.local_hospital,
              isArabic ? "إحالة" : "Referral",
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel(
          isArabic ? "هل هذا مرتبط بإصابة؟" : "Is this injury-related?",
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _injuryChip(1, isArabic ? "نعم" : "Yes"),
            const SizedBox(width: 10),
            _injuryChip(2, isArabic ? "لا" : "No"),
          ],
        ),
        const SizedBox(height: 24),
        _sectionLabel(
          isArabic ? "مستوى الوعي (AVPU)" : "Alertness Level (AVPU)",
        ),
        const SizedBox(height: 10),
        _avpuCard(
          1,
          isArabic ? "يقظ" : "Alert",
          isArabic
              ? "مستيقظ تماماً وواعٍ لمحيطه"
              : "Fully awake and aware of surroundings",
        ),
        _avpuCard(
          2,
          isArabic ? "يستجيب للصوت" : "Verbal",
          isArabic
              ? "يستجيب للصوت وقد يكون مرتبكاً"
              : "Responds to voice but may be confused",
        ),
        _avpuCard(
          3,
          isArabic ? "يستجيب للألم" : "Pain response",
          isArabic
              ? "يستجيب للمؤثرات المؤلمة فقط"
              : "Only responds to painful stimulus",
        ),
        _avpuCard(
          4,
          isArabic ? "لا يستجيب" : "Unresponsive",
          isArabic
              ? "لا استجابة للصوت أو الألم"
              : "No response to voice or pain",
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          blurRadius: 6,
          color: Colors.grey.withValues(alpha: 0.08),
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _arrivalChip(int value, IconData icon, String label) {
    final bool selected = _arrivalMode == value;

    return GestureDetector(
      onTap: () => setState(() => _arrivalMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.teal : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.teal.shade900 : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _injuryChip(int value, String label) {
    final bool selected = _injury == value;

    return GestureDetector(
      onTap: () => setState(() => _injury = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.teal.shade900 : Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _avpuCard(int value, String title, String description) {
    final bool selected = _mental == value;

    return GestureDetector(
      onTap: () => setState(() => _mental = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.teal : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? Colors.teal : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.teal.shade900 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Free-text description with mic control, live transcript, dictation
  /// language switch, and the "fill form" extraction trigger (FR-VOICE-01..03).
  Widget _buildVoiceDescribeSection(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: 6,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          onChanged: (_) => setState(() {
            if (_voiceUsed && !_isListening) _transcriptEdited = true;
            // A manual edit invalidates the stale English canonical complaint.
            _chiefComplaintEn = null;
          }),
          decoration: InputDecoration(
            labelText:
                isArabic ? "صف الأعراض التي تشعر بها" : "Describe your symptoms",
            hintText: isArabic
                ? "اكتب هنا، أو اضغط على الميكروفون وتحدث"
                : "Type here, or tap the mic and speak",
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              key: const Key('voice_mic_button'),
              tooltip: isArabic ? "الإدخال الصوتي" : "Voice input",
              onPressed: _isExtracting ? null : _toggleListening,
              icon: Icon(
                _isListening ? Icons.stop_circle : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.teal,
                size: 26,
                semanticLabel: 'Voice input, tap to describe symptoms by voice',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.translate, size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              isArabic ? "لغة الإملاء:" : "Dictation:",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            _dictationLangChip('en', 'English'),
            const SizedBox(width: 6),
            _dictationLangChip('ar', 'العربية'),
            const Spacer(),
            if (_isListening) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isArabic ? "جارٍ الاستماع…" : "Listening…",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (_descriptionController.text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('nlp_extract_button'),
              onPressed:
                  (_isExtracting || _isListening) ? null : _runExtraction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: _isExtracting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.teal,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _isExtracting
                    ? (isArabic
                        ? "جارٍ تحليل وصفك…"
                        : "Analyzing your description…")
                    : (isArabic
                        ? "تعبئة النموذج من وصفي"
                        : "Fill form from my description"),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dictationLangChip(String code, String label) {
    final bool selected = _dictationLang == code;

    return GestureDetector(
      onTap: _isListening
          ? null
          : () => setState(() => _dictationLangOverride = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.teal.shade900 : Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Extracted fields rendered as pending suggestions the patient reviews
  /// before anything touches the form (FR-NLP-03).
  Widget _buildSuggestionCard(bool isArabic) {
    final extracted = _pendingSuggestions!;
    final rows = <Widget>[];

    void addRow(IconData icon, String label, String value) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                '$label: ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final matched = _matchCanonicalSymptoms(extracted.symptoms);
    if (matched.isNotEmpty) {
      addRow(
        Icons.checklist,
        isArabic ? "الأعراض" : "Symptoms",
        matched
            .map((m) => isArabic ? (_symptomAr[m] ?? m) : m)
            .join(isArabic ? '، ' : ', '),
      );
    }
    final complaint = extracted.chiefComplaint;
    if (complaint != null && complaint.trim().isNotEmpty) {
      addRow(
        Icons.subject,
        isArabic ? "الشكوى الرئيسية" : "Main complaint",
        complaint,
      );
    }
    if (extracted.nrsPain != null) {
      addRow(
        Icons.bolt,
        isArabic ? "مستوى الألم" : "Pain level",
        '${extracted.nrsPain!.clamp(0.0, 10.0).round()}/10',
      );
    }
    if (extracted.injury != null) {
      addRow(
        Icons.personal_injury_outlined,
        isArabic ? "مرتبط بإصابة" : "Injury-related",
        extracted.injury!
            ? (isArabic ? "نعم" : "Yes")
            : (isArabic ? "لا" : "No"),
      );
    }
    if (extracted.arrivalMode != null) {
      addRow(
        Icons.directions,
        isArabic ? "طريقة الوصول" : "Arrival",
        _arrivalLabel(extracted.arrivalMode!, isArabic),
      );
    }
    addRow(
      Icons.visibility_outlined,
      isArabic ? "مستوى الوعي" : "Alertness",
      _mentalLabel(extracted.mentalStatus, isArabic),
    );

    return Container(
      key: const Key('nlp_suggestion_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.teal, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? "اقتراحات من وصفك"
                      : "Suggestions from your description",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? "هذه اقتراحات فقط — راجعها وعدّل ما تشاء قبل الإرسال."
                : "These are suggestions only — review and change anything before submitting.",
            style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
          ),
          const SizedBox(height: 10),
          ...rows,
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('nlp_dismiss_button'),
                onPressed: _dismissSuggestions,
                child: Text(
                  isArabic ? "تجاهل" : "Dismiss",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('nlp_apply_button'),
                onPressed: _applySuggestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: Text(isArabic ? "تطبيق على النموذج" : "Apply to form"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppliedBanner(bool isArabic) {
    return Container(
      key: const Key('nlp_applied_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic
                  ? "تمت تعبئة النموذج من وصفك — يرجى مراجعة كل الحقول وتعديلها قبل الإرسال."
                  : "The form was filled from your description — please review and edit every field before submitting.",
              style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    String category,
    List<String> symptoms,
    bool isArabic,
  ) {
    final displayCategory =
        isArabic ? (_categoryAr[category] ?? category) : category;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: Colors.teal,
        collapsedIconColor: Colors.teal,
        title: Row(
          children: [
            Icon(_categoryIcons[category] ?? Icons.circle, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayCategory,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptoms.map((symptom) {
                final bool isSelected = _selectedSymptoms.contains(symptom);
                final bool isRelevant =
                    _triageRelevantSymptoms.contains(symptom);

                final displaySymptom =
                    isArabic ? (_symptomAr[symptom] ?? symptom) : symptom;

                return Semantics(
                  label: '$displaySymptom${isSelected ? ", selected" : ""}',
                  button: true,
                  toggled: isSelected,
                  child: GestureDetector(
                    onTap: () => _toggleSymptom(symptom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? Colors.teal : Colors.grey.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRelevant) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          displaySymptom,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.teal.shade900
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Color(0x11000000)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              isArabic
                  ? "الألم: ${_nrsPain.toInt()}/10 · ${_selectedSymptoms.length} أعراض"
                  : "Pain: ${_nrsPain.toInt()}/10 · ${_selectedSymptoms.length} symptoms",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed:
                (_isLoading || _isExtracting) ? null : _handleGetAssessment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isArabic ? "احصل على التقييم ←" : "Get AI Assessment →",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}