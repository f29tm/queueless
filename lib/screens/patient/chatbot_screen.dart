import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/chatbot_service.dart';
import '../../services/speech_input_service.dart';
import '../../utils/app_localizer.dart';
import '../../utils/triage_levels.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ChatbotService _service = ChatbotService();
  final SpeechInputService _speech = SpeechInputService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _welcomeAdded = false;
  bool _isListening = false;
  String? _dictationLangOverride;

  static final RegExp _arabicScript = RegExp(r'[؀-ۿ]');

  // Patient-safe visit context (what the patient already sees in the app).
  String? _patientName;
  String? _visitStatus; // pre_arrival | waiting_nurse | waiting_doctor
  String? _triageLevel; // EMERGENCY | MODERATE | LOW
  String? _queueNumber;

  static const List<String> _quickRepliesEn = [
    'What does my triage result mean?',
    'How long will I wait?',
    'What happens when I arrive?',
    'What should I bring to the hospital?',
  ];

  static const List<String> _quickRepliesAr = [
    'ماذا تعني نتيجة الفرز؟',
    'كم سأنتظر؟',
    'ماذا يحدث عند وصولي للمستشفى؟',
    'ماذا يجب أن أحضر معي؟',
  ];

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  /// Dictation language: manual override first, then Arabic-script detection
  /// from what the patient is writing, then the app locale (FR-VOICE-02).
  String get _dictationLang {
    if (_dictationLangOverride != null) return _dictationLangOverride!;
    if (_arabicScript.hasMatch(_controller.text)) return 'ar';
    for (final msg in _messages.reversed) {
      if (msg.isUser) {
        return _arabicScript.hasMatch(msg.text)
            ? 'ar'
            : (_isArabic ? 'ar' : 'en');
      }
    }
    return _isArabic ? 'ar' : 'en';
  }

  @override
  void initState() {
    super.initState();
    _loadVisitContext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeAdded) {
      _welcomeAdded = true;
      _addWelcomeMessage();
    }
  }

  void _addWelcomeMessage() {
    final greeting = _patientName != null
        ? (_isArabic
            ? 'مرحباً ${_patientName!.split(' ').first}!'
            : 'Hello ${_patientName!.split(' ').first}!')
        : (_isArabic ? 'مرحباً!' : 'Hello!');

    _messages.add(_ChatMessage(
      text: _isArabic
          ? '$greeting أنا مساعدك في QueueLess. يمكنني مساعدتك في فهم نتيجة الفرز الخاصة بك، وشرح ما تتوقعه في المستشفى، أو الإجابة على أي أسئلة لديك. كيف يمكنني مساعدتك اليوم؟'
          : '$greeting I\'m your QueueLess assistant. I can help you understand your triage result, explain what to expect at the hospital, or answer any questions you have. How can I help you today?',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _speech.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Loads the patient's name and active visit so the assistant can answer
  /// personally. Only patient-visible fields are shared with the model —
  /// never confidence, entropy, or the deferral flag (FR-RESULT-02).
  Future<void> _loadVisitContext() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = userDoc.data()?['name'] as String?;

      final snap = await FirebaseFirestore.instance
          .collection('queue')
          .where('patientId', isEqualTo: uid)
          .where('status',
              whereIn: ['pre_arrival', 'waiting_nurse', 'waiting_doctor'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      String? status;
      String? level;
      String? queueNumber;
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        status = data['status'] as String?;
        level = data['triageLevel'] as String?;
        queueNumber = data['queueNumber']?.toString();
      }

      final contextLines = <String>[
        if (name != null) '- Patient first name: ${name.split(' ').first}',
        if (status != null) '- Visit status: ${_statusForModel(status)}',
        if (level != null)
          '- Urgency level shown to the patient: ${_levelLabel(level, false)}',
        if (queueNumber != null) '- Queue number: $queueNumber',
      ];
      if (contextLines.isNotEmpty) {
        _service.updateContext(contextLines.join('\n'));
      }

      if (!mounted) return;
      setState(() {
        _patientName = name;
        _visitStatus = status;
        _triageLevel = level;
        _queueNumber = queueNumber;
      });

      // A small personal touch once the assistant knows about the visit.
      if (status != null) {
        setState(() {
          _messages.add(_ChatMessage(
            text: _isArabic
                ? 'أرى أن لديك زيارة نشطة (${_statusPhrase(status!, true)}). اسألني عن أي شيء يخص الخطوات القادمة.'
                : 'I can see your active visit (${_statusPhrase(status!, false)}). Ask me anything about what happens next.',
            isUser: false,
          ));
        });
        _scrollToBottom();
      }
    } catch (_) {
      // No context — the assistant still works generically.
    }
  }

  String _statusForModel(String status) {
    switch (status) {
      case 'pre_arrival':
        return 'symptoms submitted, not yet checked in at the hospital';
      case 'waiting_nurse':
        return 'checked in, waiting for the nurse assessment';
      case 'waiting_doctor':
        return 'nurse triage complete, waiting for the doctor';
      default:
        return status;
    }
  }

  String _statusPhrase(String status, bool isArabic) {
    switch (status) {
      case 'pre_arrival':
        return isArabic
            ? 'تم إرسال الأعراض — لم يتم تسجيل الوصول بعد'
            : 'symptoms submitted — not checked in yet';
      case 'waiting_nurse':
        return isArabic
            ? 'تم تسجيل الوصول — في انتظار الممرض'
            : 'checked in — waiting for the nurse';
      case 'waiting_doctor':
        return isArabic
            ? 'اكتمل الفرز — في انتظار الطبيب'
            : 'triage complete — waiting for the doctor';
      default:
        return status;
    }
  }

  String _levelLabel(String level, bool isArabic) =>
      isArabic ? TriageLevels.labelAr(level) : TriageLevels.labelEn(level);

  Color _levelColor(String level) => TriageLevels.color(level);

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    final isArabic = _isArabic;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: trimmed, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(trimmed);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: reply, isUser: false, animate: true));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: isArabic
                ? 'عذراً، أواجه صعوبة في الاتصال الآن. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.'
                : 'Sorry, I\'m having trouble connecting right now. Please check your internet connection and try again.',
            isUser: false,
            isError: true,
            retryText: trimmed,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _toggleListening() async {
    final isArabic = _isArabic;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final ready = await _speech.init(onStatus: (status) {
      if (!mounted) return;
      if ((status == 'notListening' || status == 'done') && _isListening) {
        setState(() => _isListening = false);
      }
    });
    if (!mounted) return;

    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'الإدخال الصوتي غير متاح — يمكنك الكتابة بدلاً من ذلك.'
                : "Voice input isn't available — you can type instead.",
          ),
        ),
      );
      return;
    }

    final localeId = await _speech.resolveLocaleId(_dictationLang);
    if (!mounted) return;

    setState(() => _isListening = true);
    await _speech.start(
      localeId: localeId,
      onText: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _controller.text = text;
          _controller.selection =
              TextSelection.collapsed(offset: text.length);
          if (isFinal) _isListening = false;
        });
      },
    );
  }

  void _resetConversation() {
    _service.resetConversation();
    setState(() {
      _messages.clear();
      _isLoading = false;
      _addWelcomeMessage();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;

    return Directionality(
      textDirection: AppLocalizer.direction(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(isArabic),
        body: Column(
          children: [
            _buildDisclaimerStrip(isArabic),
            if (_visitStatus != null) _buildVisitBanner(isArabic),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildLoadingBubble();
                  }
                  return _buildMessageRow(_messages[index], isArabic);
                },
              ),
            ),
            if (!_isLoading) _buildQuickReplies(isArabic),
            _buildInputBar(isArabic),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isArabic) {
    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal, Colors.teal.shade700],
          ),
        ),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.support_agent, color: Colors.white, size: 20),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'مساعد QueueLess' : 'QueueLess Assistant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _visitStatus != null
                      ? (isArabic
                          ? 'متصل بزيارتك الحالية'
                          : 'Connected to your visit')
                      : (isArabic ? 'متصل الآن' : 'Online now'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: isArabic ? 'محادثة جديدة' : 'New conversation',
          onPressed: _isLoading ? null : _resetConversation,
          icon: const Icon(Icons.refresh, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDisclaimerStrip(bool isArabic) {
    return Container(
      width: double.infinity,
      color: Colors.teal.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined,
              size: 14, color: Colors.teal.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isArabic
                  ? 'إرشادات عامة فقط — ليست نصيحة طبية. في الحالات الطارئة اتصل بـ 999.'
                  : 'General guidance only — not medical advice. In an emergency call 999.',
              style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitBanner(bool isArabic) {
    final status = _visitStatus!;
    final level = _triageLevel;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Row(
        children: [
          if (level != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _levelColor(level).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _levelLabel(level, isArabic),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _levelColor(level),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              _statusPhrase(status, isArabic) +
                  (_queueNumber != null ? ' · $_queueNumber' : ''),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(_ChatMessage msg, bool isArabic) {
    final bubble = _buildBubble(msg, isArabic);

    if (msg.isUser) return bubble;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6, bottom: 10),
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.teal.shade100,
            child: Icon(Icons.support_agent, size: 14, color: Colors.teal.shade800),
          ),
        ),
        Expanded(child: bubble),
      ],
    );
  }

  Widget _buildBubble(_ChatMessage msg, bool isArabic) {
    return Align(
      alignment: msg.isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: msg.isUser
                ? Colors.teal
                : (msg.isError ? Colors.red.shade50 : Colors.white),
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(18),
              topEnd: const Radius.circular(18),
              bottomStart: Radius.circular(msg.isUser ? 18 : 4),
              bottomEnd: Radius.circular(msg.isUser ? 4 : 18),
            ),
            border: msg.isError ? Border.all(color: Colors.red.shade200) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.animate)
                _TypewriterText(
                  text: msg.text,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    height: 1.45,
                  ),
                  onAdvance: _scrollToBottom,
                )
              else
                Text(
                  msg.text,
                  style: TextStyle(
                    color: msg.isUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizer.time(
                      context,
                      TimeOfDay.fromDateTime(msg.time).format(context),
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      color: msg.isUser ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  if (msg.isError && msg.retryText != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _send(msg.retryText!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh,
                              size: 13, color: Colors.red.shade700),
                          const SizedBox(width: 3),
                          Text(
                            isArabic ? 'إعادة المحاولة' : 'Try again',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(18),
            topEnd: Radius.circular(18),
            bottomEnd: Radius.circular(18),
            bottomStart: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return _TypingDot(delay: Duration(milliseconds: i * 200));
          }),
        ),
      ),
    );
  }

  Widget _buildQuickReplies(bool isArabic) {
    final replies = [
      if (_visitStatus != null)
        isArabic ? 'أين موقعي في الطابور؟' : 'Where am I in the queue?',
      ...(isArabic ? _quickRepliesAr : _quickRepliesEn),
    ];

    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: replies.map((q) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(
                label: Text(q, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.teal.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onPressed: () => _send(q),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isArabic) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.translate, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'لغة الإملاء:' : 'Dictation:',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
              _dictationChip('en', 'English'),
              const SizedBox(width: 6),
              _dictationChip('ar', 'العربية'),
              if (_dictationLangOverride == null) ...[
                const SizedBox(width: 6),
                Text(
                  isArabic ? '(تلقائي)' : '(auto)',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textDirection: AppLocalizer.direction(context),
              textAlign: TextAlign.start,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _isListening
                    ? (isArabic ? 'جارٍ الاستماع…' : 'Listening…')
                    : (isArabic ? 'اسألني أي شيء…' : 'Ask me anything…'),
                hintStyle: TextStyle(
                  color: _isListening ? Colors.red.shade300 : Colors.grey,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _toggleListening,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _isListening ? Colors.red.shade50 : const Color(0xFFF5F6FA),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening ? Colors.red : Colors.teal.shade200,
                ),
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.teal,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasText || _isLoading ? Colors.teal : Colors.teal.shade200,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }

  Widget _dictationChip(String code, String label) {
    final bool selected = _dictationLang == code;

    return GestureDetector(
      onTap: _isListening
          ? null
          : () => setState(() => _dictationLangOverride = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.teal : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.teal.shade900 : Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? retryText;
  final bool animate;
  final DateTime time;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.retryText,
    this.animate = false,
  }) : time = DateTime.now();
}

/// Reveals the reply progressively, like the assistant is typing it.
class _TypewriterText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onAdvance;

  const _TypewriterText({required this.text, required this.style, this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final duration = Duration(
      milliseconds: (text.length * 12).clamp(300, 1800),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      onEnd: onAdvance,
      builder: (context, t, _) {
        final count = (text.length * t).round().clamp(0, text.length);
        return Text(text.substring(0, count), style: style);
      },
    );
  }
}

class _TypingDot extends StatefulWidget {
  final Duration delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        transform: Matrix4.translationValues(0, _animation.value, 0),
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.teal.shade300,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
