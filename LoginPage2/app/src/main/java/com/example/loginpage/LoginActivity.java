package com.example.loginpage;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.text.InputType;
import android.util.Patterns;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.Button;
import android.widget.EditText;
import android.widget.PopupMenu;
import android.widget.TextView;
import android.widget.Toast;
import android.content.SharedPreferences;


import com.google.android.material.textfield.TextInputLayout;
import com.google.firebase.firestore.FirebaseFirestore;

public class LoginActivity extends AppCompatActivity {

    TextView tvUseEmail, tvUsePhone, tvCreateAccount, tvForgotPassword;
    EditText etUser, etPassword;
    TextInputLayout tilUser;
    Button btnLogin, btnVisitor, btnStaff;

    boolean isEmailMode = true;
    FirebaseFirestore db;

    @Override
    protected void onCreate(Bundle savedInstanceState) {

        LocaleHelper.setLocale(this, LocaleHelper.getLanguage(this));

        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);

        db = FirebaseFirestore.getInstance();

        initViews();
        setEmailMode();
        setupListeners();
    }

    private void initViews() {
        tvUseEmail = findViewById(R.id.tvUseEmail);
        tvUsePhone = findViewById(R.id.tvUsePhone);

        tilUser = findViewById(R.id.tilUser);
        etUser = findViewById(R.id.etUser);
        etPassword = findViewById(R.id.etPassword);

        btnLogin = findViewById(R.id.btnLogin);
        btnVisitor = findViewById(R.id.btnVisitor);
        btnStaff = findViewById(R.id.btnStaff);

        tvCreateAccount = findViewById(R.id.tvCreateAccount);
        tvForgotPassword = findViewById(R.id.tvForgotPassword);
    }

    private void setupListeners() {
        tvUseEmail.setOnClickListener(v -> setEmailMode());
        tvUsePhone.setOnClickListener(v -> setPhoneMode());

        tvCreateAccount.setOnClickListener(v ->
                startActivity(new Intent(this, RegisterActivity.class)));

        btnVisitor.setOnClickListener(v ->
                startActivity(new Intent(this, VisitorHomeActivity.class)));

        btnStaff.setOnClickListener(v ->
                startActivity(new Intent(this, StaffLoginActivity.class)));

        tvForgotPassword.setOnClickListener(v ->
                startActivity(new Intent(this, ResetPasswordActivity.class)));

        btnLogin.setOnClickListener(v -> validateLogin());
    }

    // ------------------------------------------------------------
    // SWITCH BETWEEN EMAIL & PHONE MODE
    // ------------------------------------------------------------
    private void setEmailMode() {
        isEmailMode = true;
        tilUser.setHint("Email Address");
        etUser.setInputType(InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);

        tvUseEmail.setTextColor(Color.parseColor("#1A73E8"));
        tvUsePhone.setTextColor(Color.parseColor("#777777"));
    }

    private void setPhoneMode() {
        isEmailMode = false;
        tilUser.setHint("Phone Number");
        etUser.setInputType(InputType.TYPE_CLASS_NUMBER);

        tvUsePhone.setTextColor(Color.parseColor("#1A73E8"));
        tvUseEmail.setTextColor(Color.parseColor("#777777"));
    }

    // ------------------------------------------------------------
    // FIRESTORE LOGIN FOR EMAIL + PHONE + OTP
    // ------------------------------------------------------------
    private void validateLogin() {

        tilUser.setError(null);
        etPassword.setError(null);

        String userInput = etUser.getText().toString().trim();
        String password = etPassword.getText().toString().trim();

        // ----------------------------
        // VALIDATION
        // ----------------------------
        if (isEmailMode) {
            if (!Patterns.EMAIL_ADDRESS.matcher(userInput).matches()) {
                tilUser.setError("Invalid email address");
                return;
            }
        } else {
            if (!userInput.matches("\\d{10,15}")) {
                tilUser.setError("Enter a valid phone number");
                return;
            }
        }

        if (password.isEmpty()) {
            etPassword.setError("Password cannot be empty");
            return;
        }

        // ----------------------------
        // FIRESTORE LOOKUP
        // ----------------------------
        String searchField = isEmailMode ? "email" : "phone";

        db.collection("users")
                .whereEqualTo(searchField, userInput)
                .get()
                .addOnSuccessListener(query -> {

                    if (query.isEmpty()) {
                        tilUser.setError(isEmailMode ?
                                "No account found with this email" :
                                "No account found with this phone number");
                        return;
                    }

                    // 1️⃣ Extract fields FIRST
                    String savedPassword = query.getDocuments().get(0).getString("password");
                    String role = query.getDocuments().get(0).getString("role");
                    String firstName = query.getDocuments().get(0).getString("firstName");

                    // 2️⃣ Validate password
                    if (!password.equals(savedPassword)) {
                        etPassword.setError("Incorrect password");
                        return;
                    }

                    // 3️⃣ Save name AFTER defining firstName
                    SharedPreferences prefs = getSharedPreferences("UserData", MODE_PRIVATE);
                    prefs.edit().putString("patient_name", firstName).apply();

                    // 4️⃣ Send OTP
                    if (isEmailMode) {
                        sendOtpToEmail(userInput, role);
                    } else {
                        String userEmail = query.getDocuments().get(0).getString("email");
                        String masked = maskEmail(userEmail);
                        sendOtpToEmailForPhoneLogin(userEmail, masked, role);
                    }

                })
                .addOnFailureListener(e ->
                        Toast.makeText(this, "Login failed: " + e.getMessage(), Toast.LENGTH_SHORT).show()
                );
    }

        // ------------------------------------------------------------
    // SEND OTP EMAIL FUNCTION
    // ------------------------------------------------------------
    private void sendOtpToEmail(String email, String role) {

        String otp = String.valueOf((int) (Math.random() * 900000) + 100000);

        String masked = maskEmail(email);
        long expireTime = System.currentTimeMillis() + 120000; // 2 minutes

        Intent intent = new Intent(LoginActivity.this, VerificationActivity.class);
        intent.putExtra("otp", otp);

        // ✔ Correct keys
        intent.putExtra("maskedEmail", masked);   // shown on UI
        intent.putExtra("email", email);          // real email for sending OTP

        intent.putExtra("method", "email");
        intent.putExtra("role", role);
        intent.putExtra("expireTime", expireTime);
        intent.putExtra("method", "reset");

        startActivity(intent);

        // Send OTP in background
        new Thread(() -> {
            try {
                EmailSender.sendEmail(
                        email,
                        "Your Login Verification Code",
                        "Your OTP is: " + otp
                );
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }




    // ------------------------------------------------------------
    // LANGUAGE MENU
    // ------------------------------------------------------------
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_language, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {

        if (item.getItemId() == R.id.action_language) {

            PopupMenu popup = new PopupMenu(this, findViewById(R.id.action_language));
            popup.getMenuInflater().inflate(R.menu.menu_language, popup.getMenu());

            popup.setOnMenuItemClickListener(i -> {
                if (i.getItemId() == R.id.lang_en) {
                    LocaleHelper.setLocale(this, "en");
                } else if (i.getItemId() == R.id.lang_ar) {
                    LocaleHelper.setLocale(this, "ar");
                }
                recreate();
                return true;
            });

            popup.show();
            return true;
        }

        return super.onOptionsItemSelected(item);
    }
    private String maskEmail(String email) {
        int index = email.indexOf("@");
        if (index <= 2) {
            // Very short name → show 1 letter
            return email.charAt(0) + "***" + email.substring(index);
        }

        String visible = email.substring(0, 2); // first 2 letters visible
        String domain = email.substring(index);

        return visible + "***" + domain;
    }
    private void sendOtpToEmailForPhoneLogin(String realEmail, String maskedEmail, String role) {

        String otp = String.valueOf((int) (Math.random() * 900000) + 100000);
        long expireTime = System.currentTimeMillis() + 120000;

        Intent intent = new Intent(LoginActivity.this, VerificationActivity.class);
        intent.putExtra("otp", otp);

        // ✔ Correct keys
        intent.putExtra("maskedEmail", maskedEmail); // UI
        intent.putExtra("email", realEmail);         // sending OTP

        intent.putExtra("method", "phone");
        intent.putExtra("role", role);
        intent.putExtra("expireTime", expireTime);

        startActivity(intent);

        new Thread(() -> {
            try {
                EmailSender.sendEmail(
                        realEmail,
                        "Your Login Verification Code",
                        "Your OTP is: " + otp
                );
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }




}


