package com.example.loginpage;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.os.Bundle;
import android.text.InputFilter;
import android.util.Patterns;
import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.Button;
import android.widget.EditText;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.datepicker.CalendarConstraints;
import com.google.android.material.datepicker.DateValidatorPointBackward;
import com.google.android.material.datepicker.MaterialDatePicker;
import com.google.android.material.textfield.TextInputLayout;
import com.google.firebase.firestore.FirebaseFirestore;

import java.util.Arrays;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class RegisterActivity extends AppCompatActivity {

    // TextInputLayouts
    TextInputLayout tilNationalID, tilFirstName, tilMiddleName, tilLastName, tilEmail, tilPhone,
            tilDob, tilNationality, tilGender, tilPassword, tilConfirmPassword;

    // EditTexts
    EditText etNationalID, etFirstName, etMiddleName, etLastName, etEmail, etPhone, etDob,
            etPassword, etConfirmPassword;

    AutoCompleteTextView etGender;
    AutoCompleteTextView etNationality;

    Button btnCreateAccount;
    FirebaseFirestore db;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_register);

        db = FirebaseFirestore.getInstance();
        initViews();
        setupToolbar();
        setupDropdowns();
        setupNationalityList();
        setupDobPicker();

        enforceDigitsOnly(etNationalID, 15);
        enforceDigitsOnly(etPhone, 10);

        btnCreateAccount.setOnClickListener(v -> validateAllFields());
    }

    private void initViews() {
        tilNationalID = findViewById(R.id.tilNationalID);
        tilFirstName = findViewById(R.id.tilFirstName);
        tilMiddleName = findViewById(R.id.tilMiddleName);
        tilLastName = findViewById(R.id.tilLastName);
        tilEmail = findViewById(R.id.tilEmail);
        tilPhone = findViewById(R.id.tilPhone);
        tilDob = findViewById(R.id.tilDob);
        tilNationality = findViewById(R.id.tilNationality);
        tilGender = findViewById(R.id.tilGender);
        tilPassword = findViewById(R.id.tilPassword);
        tilConfirmPassword = findViewById(R.id.tilConfirmPassword);

        etNationalID = findViewById(R.id.etNationalID);
        etFirstName = findViewById(R.id.etFirstName);
        etMiddleName = findViewById(R.id.etMiddleName);
        etLastName = findViewById(R.id.etLastName);
        etEmail = findViewById(R.id.etEmail);
        etPhone = findViewById(R.id.etPhone);
        etDob = findViewById(R.id.etDob);
        enforceLettersOnly(etFirstName);
        enforceLettersOnly(etMiddleName);
        enforceLettersOnly(etLastName);

        etNationality = findViewById(R.id.etNationality);
        etGender = findViewById(R.id.etGender);

        etPassword = findViewById(R.id.etPassword);
        etConfirmPassword = findViewById(R.id.etConfirmPassword);

        btnCreateAccount = findViewById(R.id.btnCreateAccount);
    }

    private void setupToolbar() {
        MaterialToolbar toolbar = findViewById(R.id.topAppBar);
        toolbar.setNavigationOnClickListener(v -> finish());
    }

    // ------------------------------
    // FIXED GENDER DROPDOWN
    // ------------------------------
    private void setupDropdowns() {
        List<String> genderList = Arrays.asList("Male", "Female");

        ArrayAdapter<String> genderAdapter =
                new ArrayAdapter<>(this, android.R.layout.simple_dropdown_item_1line, genderList);

        etGender.setAdapter(genderAdapter);      // IMPORTANT FIX
        etGender.setOnClickListener(v -> etGender.showDropDown());
    }

    private void setupDobPicker() {
        etDob.setOnClickListener(v -> {
            Calendar now = Calendar.getInstance();

            CalendarConstraints constraints = new CalendarConstraints.Builder()
                    .setValidator(DateValidatorPointBackward.before(now.getTimeInMillis()))
                    .build();

            MaterialDatePicker<Long> picker = MaterialDatePicker.Builder.datePicker()
                    .setTitleText("Select Date of Birth")
                    .setSelection(now.getTimeInMillis())
                    .setCalendarConstraints(constraints)
                    .build();

            picker.addOnPositiveButtonClickListener(selection -> {
                Calendar c = Calendar.getInstance();
                c.setTimeInMillis(selection);
                etDob.setText(String.format("%02d/%02d/%04d",
                        c.get(Calendar.DAY_OF_MONTH),
                        c.get(Calendar.MONTH) + 1,
                        c.get(Calendar.YEAR)));
            });

            picker.show(getSupportFragmentManager(), "DOB_PICKER");
        });
    }

    private void enforceDigitsOnly(EditText editText, int maxLength) {
        InputFilter digitsOnly = (source, start, end, dest, dstart, dend) -> {
            for (int i = start; i < end; i++)
                if (!Character.isDigit(source.charAt(i)))
                    return "";
            return null;
        };
        editText.setFilters(new InputFilter[]{digitsOnly, new InputFilter.LengthFilter(maxLength)});
    }

    private void validateAllFields() {
        boolean valid = true;

        if (etFirstName.getText().toString().isEmpty()) {
            tilFirstName.setError("Required");
            valid = false;
        } else tilFirstName.setError(null);

        if (etMiddleName.getText().toString().isEmpty()) {
            tilMiddleName.setError("Required");
            valid = false;
        } else tilMiddleName.setError(null);

        if (etLastName.getText().toString().isEmpty()) {
            tilLastName.setError("Required");
            valid = false;
        } else tilLastName.setError(null);

        if (!etNationalID.getText().toString().matches("\\d{15}")) {
            tilNationalID.setError("National ID must be 15 digits");
            valid = false;
        } else tilNationalID.setError(null);

        if (etDob.getText().toString().isEmpty()) {
            tilDob.setError("Required");
            valid = false;
        } else tilDob.setError(null);

        String email = etEmail.getText().toString().trim();
        if (!Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            tilEmail.setError("Invalid email");
            valid = false;
        } else tilEmail.setError(null);

        String phone = etPhone.getText().toString().trim();

// UAE mobile number must start with 05 + 8 digits
        if (!phone.matches("^05\\d{8}$")) {
            tilPhone.setError("Enter a valid UAE number (e.g., 0501234567)");
            valid = false;
        } else {
            tilPhone.setError(null);
        }


        String pass = etPassword.getText().toString();
        if (!isStrongPassword(pass)) {
            tilPassword.setError("Weak password");
            valid = false;
        } else tilPassword.setError(null);

        if (!pass.equals(etConfirmPassword.getText().toString())) {
            tilConfirmPassword.setError("Passwords do not match");
            valid = false;
        } else tilConfirmPassword.setError(null);

        if (!valid) return;

        checkUniqueFields(email, etPhone.getText().toString(), etNationalID.getText().toString());
    }

    private void checkUniqueFields(String email, String phone, String nationalID) {
        db.collection("users")
                .whereEqualTo("email", email)
                .get()
                .addOnSuccessListener(q1 -> {
                    if (!q1.isEmpty()) {
                        tilEmail.setError("Email already exists");
                        return;
                    }

                    db.collection("users")
                            .whereEqualTo("phone", phone)
                            .get()
                            .addOnSuccessListener(q2 -> {
                                if (!q2.isEmpty()) {
                                    tilPhone.setError("Phone already exists");
                                    return;
                                }

                                db.collection("users")
                                        .whereEqualTo("nationalID", nationalID)
                                        .get()
                                        .addOnSuccessListener(q3 -> {
                                            if (!q3.isEmpty()) {
                                                tilNationalID.setError("National ID already exists");
                                                return;
                                            }

                                            saveUserToDatabase(UUID.randomUUID().toString());
                                        });
                            });
                });
    }

    private void saveUserToDatabase(String uid) {

        String email = etEmail.getText().toString();
        String maskedEmail = maskEmail(email);

        // Generate OTP
        String otp = String.valueOf((int)(Math.random() * 900000) + 100000);

        long otpCreatedAt = System.currentTimeMillis();
        long expireTime = otpCreatedAt + 120000; // 2 min

        Map<String, Object> user = new HashMap<>();
        user.put("nationalID", etNationalID.getText().toString());
        user.put("firstName", etFirstName.getText().toString());
        user.put("middleName", etMiddleName.getText().toString());
        user.put("lastName", etLastName.getText().toString());
        user.put("email", email);
        user.put("phone", etPhone.getText().toString());
        user.put("dob", etDob.getText().toString());
        user.put("gender", etGender.getText().toString());
        user.put("nationality", etNationality.getText().toString());
        user.put("password", etPassword.getText().toString());
        user.put("role", "patient");
        user.put("otpCreatedAt", otpCreatedAt);

        db.collection("users")
                .document(uid)
                .set(user)
                .addOnSuccessListener(a -> {

                    // SEND OTP EMAIL (background thread)
                    new Thread(() -> {
                        try {
                            EmailSender.sendEmail(
                                    email,
                                    "Your Registration Verification Code",
                                    "Your OTP is: " + otp
                            );
                        } catch (Exception e) { e.printStackTrace(); }
                    }).start();

                    // OPEN VERIFICATION PAGE
                    Intent i = new Intent(RegisterActivity.this, VerificationActivity.class);
                    i.putExtra("otp", otp);
                    i.putExtra("maskedEmail", maskedEmail);
                    i.putExtra("email", email); // real email used for sending & resending
                    i.putExtra("role", "patient");
                    i.putExtra("expireTime", expireTime); // same style as login page

                    startActivity(i);
                    finish();
                });
    }


    private boolean isStrongPassword(String pwd) {
        return pwd.length() >= 8 &&
                pwd.matches(".*[A-Z].*") &&
                pwd.matches(".*[a-z].*") &&
                pwd.matches(".*\\d.*") &&
                pwd.matches(".*[@#$%^&+=!*.?].*");
    }

    private String maskEmail(String email) {
        int index = email.indexOf("@");
        if (index <= 2) {
            return email.charAt(0) + "*****" + email.substring(index);
        }
        return email.substring(0, 2) + "*****" + email.substring(index);
    }

    // ------------------------------
    // FIXED NATIONALITY DROPDOWN
    // ------------------------------
    private void setupNationalityList() {

        List<String> nationalityList = Arrays.asList(
                "United Arab Emirates", "Saudi Arabia", "Qatar", "Kuwait", "Bahrain", "Oman",
                "Jordan", "Lebanon", "Syria", "Iraq", "Palestine", "Egypt", "Sudan", "Morocco",
                "Algeria", "Tunisia", "Yemen",
                "India", "Pakistan", "Bangladesh", "Philippines", "Sri Lanka", "Nepal"
        );

        ArrayAdapter<String> nationalityAdapter =
                new ArrayAdapter<>(this, android.R.layout.simple_dropdown_item_1line, nationalityList);

        etNationality.setAdapter(nationalityAdapter);

        // Allow typing and show filtered dropdown
        etNationality.setThreshold(1); // Start filtering after 1 character

        //  Show dropdown menu when clicking the field
        etNationality.setOnClickListener(v -> etNationality.showDropDown());
    }

    private void enforceUAENumber(EditText editText) {
        editText.addTextChangedListener(new android.text.TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                String input = s.toString();

                if (input.length() == 1 && !input.equals("0")) {
                    editText.setText("0");
                    editText.setSelection(1);
                }
                else if (input.length() == 2 && !input.equals("05")) {
                    editText.setText("05");
                    editText.setSelection(2);
                }
            }

            @Override
            public void afterTextChanged(android.text.Editable s) {}
        });
    }
    private void enforceLettersOnly(EditText editText) {
        InputFilter lettersOnlyFilter = (source, start, end, dest, dstart, dend) -> {
            for (int i = start; i < end; i++) {
                if (!Character.isLetter(source.charAt(i)) && !Character.isWhitespace(source.charAt(i))) {
                    return ""; // reject numbers and symbols
                }
            }
            return null; // allow normal input
        };

        editText.setFilters(new InputFilter[]{lettersOnlyFilter, new InputFilter.LengthFilter(30)});
    }


}
