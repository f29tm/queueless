package com.example.loginpage;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.text.InputType;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Button;
import android.widget.Toast;
import android.view.View;

import com.google.firebase.firestore.FirebaseFirestore;

public class StaffLoginActivity extends AppCompatActivity {

    TextView tvUseEmail, tvUseStaffId, tvForgotPassword;
    EditText etStaffUser, etStaffPassword;
    Button btnStaffLogin;
    boolean loginWithEmail = true;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_staff_login);

        initViews();

        tvUseEmail.setOnClickListener(v -> setEmailMode());
        tvUseStaffId.setOnClickListener(v -> setStaffIdMode());

        btnStaffLogin.setOnClickListener(v -> validateLogin());

        tvForgotPassword.setOnClickListener(v ->
                startActivity(new Intent(this, ResetPasswordActivity.class)));
    }

    private void initViews() {
        tvUseEmail = findViewById(R.id.tvUseEmail);
        tvUseStaffId = findViewById(R.id.tvUseStaffId);
        tvForgotPassword = findViewById(R.id.tvForgotPassword);

        etStaffUser = findViewById(R.id.etStaffUser);
        etStaffPassword = findViewById(R.id.etStaffPassword);

        btnStaffLogin = findViewById(R.id.btnStaffLogin);
    }

    private void setEmailMode() {
        loginWithEmail = true;
        etStaffUser.setHint("Email Address");
        etStaffUser.setInputType(InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);

        tvUseEmail.setTextColor(Color.parseColor("#2E7D32"));
        tvUseStaffId.setTextColor(Color.parseColor("#777777"));
    }

    private void setStaffIdMode() {
        loginWithEmail = false;
        etStaffUser.setHint("Staff ID (e.g., ST12345)");
        etStaffUser.setInputType(InputType.TYPE_CLASS_TEXT);

        tvUseEmail.setTextColor(Color.parseColor("#777777"));
        tvUseStaffId.setTextColor(Color.parseColor("#2E7D32"));
    }

    private void validateLogin() {

        String user = etStaffUser.getText().toString().trim();
        String pass = etStaffPassword.getText().toString().trim();

        FirebaseFirestore db = FirebaseFirestore.getInstance();

        boolean isEmail = android.util.Patterns.EMAIL_ADDRESS.matcher(user).matches();

        // Red warning message
        TextView tvStaffError = findViewById(R.id.tvStaffError);
        tvStaffError.setVisibility(View.GONE); // hide it first

        db.collection("staff")
                .whereEqualTo(isEmail ? "email" : "staffId", user)
                .get()
                .addOnSuccessListener(query -> {

                    // ❌ NO STAFF ACCOUNT FOUND
                    if (query.isEmpty()) {
                        tvStaffError.setText("⚠ You are not authorized as hospital staff.");
                        tvStaffError.setVisibility(View.VISIBLE);
                        return;
                    }

                    // Staff Document
                    var doc = query.getDocuments().get(0);
                    String storedPassword = doc.getString("password");

                    // ❌ WRONG PASSWORD
                    if (!pass.equals(storedPassword)) {
                        etStaffPassword.setError("Incorrect password");
                        return;
                    }

                    // Password correct → proceed with OTP
                    String email = doc.getString("email");

                    String otp = String.valueOf((int) (Math.random() * 900000) + 100000);
                    String masked = maskEmail(email);

                    Intent i = new Intent(StaffLoginActivity.this, VerificationActivity.class);
                    i.putExtra("otp", otp);
                    i.putExtra("maskedEmail", masked);
                    i.putExtra("email", email);
                    i.putExtra("method", isEmail ? "staff_email" : "staff_id");
                    i.putExtra("role", "staff");
                    i.putExtra("expireTime", System.currentTimeMillis() + 120000);

                    startActivity(i);

                    // Send OTP Email
                    new Thread(() -> {
                        try {
                            EmailSender.sendEmail(
                                    email,
                                    "Your Staff Verification Code",
                                    "Your OTP is: " + otp
                            );
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }).start();

                })
                .addOnFailureListener(e ->
                        Toast.makeText(this, "Error connecting to Firestore", Toast.LENGTH_SHORT).show()
                );
    }



    // ---------------------------
    // MASK EMAIL FUNCTION
    // ---------------------------
    private String maskEmail(String email) {
        int index = email.indexOf("@");
        if (index <= 2) {
            return email.charAt(0) + "***" + email.substring(index);
        }

        return email.substring(0, 2) + "***" + email.substring(index);
    }

}
