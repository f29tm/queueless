import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailSender {
  static Future<void> sendEmail({
    required String toEmail,
    required String subject,
    required String otp,
  }) async {
    const String fromEmail = "aishaalsholi42@gmail.com";
    const String appPassword = "veiadcipkmidxsjp";

    final smtpServer = gmail(fromEmail, appPassword);

    final messageBody = '''
<html>
<body style='font-family: Arial; color:#333; padding:20px;'>
  <h2 style='color:#1A73E8;'>QueueLess Verification</h2>
  <p>Hello,</p>
  <p>Your one-time verification code is:</p>
  <div style='font-size:32px; font-weight:bold; color:#1A73E8; border:2px solid #1A73E8; padding:10px 20px; display:inline-block; border-radius:8px; margin:15px 0;'>
    $otp
  </div>
  <p>This code will expire in <b>2 minutes</b>. Please do not share this code with anyone.</p>
  <p>If you did not request this code, you can safely ignore this email.</p>
  <br><p>Best regards,<br><b>SmartQueue Team</b></p>
</body>
</html>
''';

    final message = Message()
      ..from = const Address(fromEmail, 'SmartQueue App')
      ..recipients.add(toEmail)
      ..subject = subject
      ..html = messageBody;

    try {
      await send(message, smtpServer);
    } catch (e) {
      // Intentionally handling error without printing in production
    }
  }
}
