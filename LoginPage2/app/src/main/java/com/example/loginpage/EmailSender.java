package com.example.loginpage;

import java.util.Properties;
import javax.mail.Authenticator;
import javax.mail.Message;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;

public class EmailSender {

    public static void sendEmail(String toEmail, String subject, String otp) throws Exception {

        final String fromEmail = "aishaalsholi42@gmail.com";
        final String appPassword = "veiadcipkmidxsjp";  // APP PASSWORD

        Properties props = new Properties();
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "465");
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.socketFactory.port", "465");
        props.put("mail.smtp.socketFactory.class", "javax.net.ssl.SSLSocketFactory");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.mime.charset", "UTF-8");

        Session session = Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(fromEmail, appPassword);
            }
        });

        MimeMessage msg = new MimeMessage(session);

        // Show SmartQueue App as sender name
        msg.setFrom(new InternetAddress(fromEmail, "SmartQueue App"));
        msg.addRecipient(Message.RecipientType.TO, new InternetAddress(toEmail));
        msg.setSubject(subject, "UTF-8");

        // ---- HTML EMAIL TEMPLATE ----
        String messageBody =
                "<html>" +
                        "<body style='font-family: Arial; color:#333; padding:20px;'>" +

                        "<h2 style='color:#1A73E8;'>QueueLess Verification</h2>" +

                        "<p>Hello,</p>" +

                        "<p>Your one-time verification code is:</p>" +

                        "<div style='font-size:32px; font-weight:bold; color:#1A73E8; " +
                        "border:2px solid #1A73E8; padding:10px 20px; display:inline-block; " +
                        "border-radius:8px; margin:15px 0;'>" +
                        otp +
                        "</div>" +

                        "<p>This code will expire in <b>2 minutes</b>. " +
                        "Please do not share this code with anyone.</p>" +

                        "<p>If you did not request this code, you can safely ignore this email.</p>" +

                        "<br><p>Best regards,<br><b>SmartQueue Team</b></p>" +

                        "</body></html>";

        msg.setContent(messageBody, "text/html; charset=UTF-8");

        Transport.send(msg);
    }
}
