package com.example.loginpage;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.text.Editable;
import android.text.TextWatcher;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

public class VerificationActivity extends AppCompatActivity {

    private String otp = "";
    private String maskedEmail = "";
    private String realEmail = "";
    private String role = "";
    private String method = "";
    private long expireTime;

    EditText otp1, otp2, otp3, otp4, otp5, otp6;
    TextView tvUserInfo, tvResend, tvTimer;
    CountDownTimer countDownTimer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_verification);

        // ----------------------------
        // READ DATA FROM INTENT
        // ----------------------------
        otp = getIntent().getStringExtra("otp");

        // FIXED: read masked email correctly
        maskedEmail = getIntent().getStringExtra("maskedEmail");  // <– FIX
        realEmail   = getIntent().getStringExtra("email");        // <– real email for sending

        method = getIntent().getStringExtra("method");
        role = getIntent().getStringExtra("role");
        if (role == null || role.trim().isEmpty()) role = "patient";

        // FIXED: handle expire time for BOTH login & registration
        long otpCreatedAt = getIntent().getLongExtra("otpCreatedAt", 0);
        long directExpire = getIntent().getLongExtra("expireTime", 0);

        if (directExpire > 0) {
            // Login flow sent expireTime
            expireTime = directExpire;
        } else {
            // Registration flow sent otpCreatedAt
            expireTime = otpCreatedAt + 120000; // 2 minutes
        }

        // ----------------------------
        // BIND VIEWS
        // ----------------------------
        tvUserInfo = findViewById(R.id.tvUserInfo);
        tvResend  = findViewById(R.id.tvResend);
        tvTimer   = findViewById(R.id.tvTimer);

        otp1 = findViewById(R.id.otp1);
        otp2 = findViewById(R.id.otp2);
        otp3 = findViewById(R.id.otp3);
        otp4 = findViewById(R.id.otp4);
        otp5 = findViewById(R.id.otp5);
        otp6 = findViewById(R.id.otp6);

        Button btnVerify = findViewById(R.id.btnVerify);

        // FIXED: Show masked only
        tvUserInfo.setText(maskedEmail);

        setupOtpInputs();
        startTimer();

        btnVerify.setOnClickListener(v -> checkOtp());

        tvResend.setOnClickListener(v -> {
            if (tvResend.isEnabled()) resendOtp();
        });
    }

    // ----------------------------------------------------
    // OTP AUTO FOCUS
    // ----------------------------------------------------
    private void setupOtpInputs() {
        addOtpTextWatcher(otp1, otp2);
        addOtpTextWatcher(otp2, otp3);
        addOtpTextWatcher(otp3, otp4);
        addOtpTextWatcher(otp4, otp5);
        addOtpTextWatcher(otp5, otp6);
    }

    private void addOtpTextWatcher(EditText current, EditText next) {
        current.addTextChangedListener(new TextWatcher() {
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (s.length() == 1 && next != null) next.requestFocus();
            }
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void afterTextChanged(Editable s) {}
        });
    }

    // ----------------------------------------------------
    // COUNTDOWN TIMER
    // ----------------------------------------------------
    private void startTimer() {

        long timeLeft = expireTime - System.currentTimeMillis();

        if (timeLeft <= 0) {
            tvTimer.setText("Expired");
            tvResend.setEnabled(true);
            tvResend.setAlpha(1f);
            disableOtpInputs();
            return;
        }

        tvResend.setEnabled(false);
        tvResend.setAlpha(0.4f);

        if (countDownTimer != null) countDownTimer.cancel();

        countDownTimer = new CountDownTimer(timeLeft, 1000) {
            @Override
            public void onTick(long millisUntilFinished) {
                int minutes = (int) (millisUntilFinished / 1000) / 60;
                int seconds = (int) (millisUntilFinished / 1000) % 60;
                tvTimer.setText(String.format("%02d:%02d", minutes, seconds));
            }

            @Override
            public void onFinish() {
                tvTimer.setText("Expired");
                tvResend.setEnabled(true);
                tvResend.setAlpha(1f);
                disableOtpInputs();
            }
        }.start();
    }

    private void disableOtpInputs() {
        otp1.setEnabled(false);
        otp2.setEnabled(false);
        otp3.setEnabled(false);
        otp4.setEnabled(false);
        otp5.setEnabled(false);
        otp6.setEnabled(false);
    }

    // ----------------------------------------------------
    // OTP CHECK
    // ----------------------------------------------------
    private void checkOtp() {

        if (System.currentTimeMillis() > expireTime) {
            Toast.makeText(this, "Code expired. Please resend.", Toast.LENGTH_SHORT).show();
            return;
        }

        String enteredOtp =
                otp1.getText().toString() +
                        otp2.getText().toString() +
                        otp3.getText().toString() +
                        otp4.getText().toString() +
                        otp5.getText().toString() +
                        otp6.getText().toString();

        if (enteredOtp.length() < 6) {
            Toast.makeText(this, "Enter all 6 digits", Toast.LENGTH_SHORT).show();
            return;
        }

        if (!enteredOtp.equals(otp)) {
            Toast.makeText(this, "Incorrect code", Toast.LENGTH_SHORT).show();
            return;
        }

        goToNextScreen();
    }

    // ----------------------------------------------------
    // RESEND OTP
    // ----------------------------------------------------
    private void resendOtp() {

        otp = String.valueOf((int) (Math.random() * 900000) + 100000);

        expireTime = System.currentTimeMillis() + 120000;
        startTimer();

        Toast.makeText(this, "New code sent", Toast.LENGTH_SHORT).show();

        new Thread(() -> {
            try {
                EmailSender.sendEmail(
                        realEmail,
                        "New Verification Code",
                        "Your new OTP is: " + otp
                );
            } catch (Exception e) { e.printStackTrace(); }
        }).start();
    }

    // ----------------------------------------------------
    // REDIRECT
    // ----------------------------------------------------
    private void goToNextScreen() {
        Intent intent;

        switch (role.toLowerCase()) {
            case "staff":
                intent = new Intent(this, StaffHubActivity.class);
                break;
            case "patient":
                intent = new Intent(this, PatientHubActivity.class);
                break;
            default:
                intent = new Intent(this, VisitorHomeActivity.class);
                break;
        }

        startActivity(intent);
        finish();
    }
}


