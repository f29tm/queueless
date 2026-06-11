import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/triage_service.dart';
import '../../services/encryption_service.dart';
import 'symptom_result_screen.dart';
import '../../utils/app_localizer.dart';

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
  const SymptomAssessmentScreen({super.key});

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
    _fetchProfile();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
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
    } catch (_) {}
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

  Future<void> _handleGetAssessment() async {
    final isArabic = _isArabic;
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
      String chiefComplaint = _selectedSymptoms.join(', ');

      if (description.isNotEmpty) {
        chiefComplaint += chiefComplaint.isNotEmpty
            ? '. Patient says: $description'
            : description;
      }

      if (chiefComplaint.isEmpty) {
        chiefComplaint = 'general complaint';
      }

      final request = Stage1Request(
        chiefComplaint: chiefComplaint,
        age: _age!,
        sex: _sex!,
        pain: _nrsPain > 0 ? 1 : 2,
        nrsPain: _nrsPain,
        mental: _mental,
        arrivalMode: _arrivalMode,
        injury: _injury,
        patientsPerHour: 8,
      );

      final result = await TriageService.predictStage1(request);

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
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write sensitive text fields encrypted via Cloud Function
      await EncryptionService.saveSymptomData(
        docId: ref.id,
        data: {
          'patientId': uid,
          'symptoms': _selectedSymptoms.join(', '),
          'description': description,
          'chiefComplaint': chiefComplaint,
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

    return Directionality(
      textDirection: AppLocalizer.direction(context),
      child: Scaffold(
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
      ),
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
        TextField(
          controller: _descriptionController,
          maxLines: 6,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText:
                isArabic ? "صف الأعراض التي تشعر بها" : "Describe your symptoms",
            alignLabelWithHint: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

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
              Slider(
                value: _nrsPain,
                min: 0,
                max: 10,
                divisions: 10,
                activeColor: _painColor,
                onChanged: (v) => setState(() => _nrsPain = v),
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

                return GestureDetector(
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
            onPressed: _isLoading ? null : _handleGetAssessment,
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