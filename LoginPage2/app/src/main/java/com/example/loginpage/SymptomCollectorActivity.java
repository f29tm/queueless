package com.example.loginpage;

import android.content.Intent;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Activity for collecting patient symptoms using both multiple choice (checkboxes) and free-text input,
 * and performing a combined rule-based triage. This is a dedicated Triage Assessment screen
 */
public class SymptomCollectorActivity extends AppCompatActivity {

    private EditText symptomInputEditText;
    private Button triageButton;
    private TextView resultTextView;

    // Checkbox elements for MCQ selection
    private CheckBox cbChestPain, cbShortnessBreath, cbSevereBleeding, cbLossConsciousness, cbHighFever, cbFracture, cbPersistentVomiting;

    // Define sets of keywords for rule-based sorting in free-text input
    private static final Set<String> EMERGENCY_KEYWORDS = new HashSet<>(Arrays.asList(
            "unconscious", "stroke", "paralysis", "anaphylaxis", "severe burn"
    ));
    private static final Set<String> URGENT_KEYWORDS = new HashSet<>(Arrays.asList(
            "abdominal pain", "deep cut", "dizziness", "moderate pain", "fever over 39", "severe headache"
    ));

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_symptom_collector);

        // Initialize UI components for free-text and result
        symptomInputEditText = findViewById(R.id.symptomInputEditText);
        triageButton = findViewById(R.id.triageButton);
        resultTextView = findViewById(R.id.resultTextView);

        // Initialize Checkbox components (MCQ)
        cbChestPain = findViewById(R.id.cb_chest_pain);
        cbShortnessBreath = findViewById(R.id.cb_shortness_breath);
        cbSevereBleeding = findViewById(R.id.cb_severe_bleeding);
        cbLossConsciousness = findViewById(R.id.cb_loss_consciousness);
        cbHighFever = findViewById(R.id.cb_high_fever);
        cbFracture = findViewById(R.id.cb_fracture);
        cbPersistentVomiting = findViewById(R.id.cb_persistent_vomiting);

        // Set up the button click listener
        triageButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                collectAndSortSymptoms();
            }
        });

        // Initialize and set up the Bottom Navigation Bar
        setupBottomNavigation();
    }

    /**
     * Initializes the Bottom Navigation View and sets up the item selection listener for consistent app-wide navigation.
     */
    private void setupBottomNavigation() {
        BottomNavigationView bottomNavigationView = findViewById(R.id.bottom_navigation_bar);

        bottomNavigationView.setOnItemSelectedListener(new BottomNavigationView.OnItemSelectedListener() {
            @Override
            public boolean onNavigationItemSelected(@NonNull MenuItem item) {
                int id = item.getItemId();
                Intent intent = null;

                if (id == R.id.nav_home) {
                    // Navigate to the PatientHubActivity (Home/Dashboard)
                    intent = new Intent(getApplicationContext(), PatientHubActivity.class);
                } else if (id == R.id.nav_chatbot) {
                    // Chatbot is now a separate, non-implemented destination.
                    Toast.makeText(SymptomCollectorActivity.this, "Chatbot Feature", Toast.LENGTH_SHORT).show();
                    return true; // Stay on the current screen but show toast
                } else if (id == R.id.nav_records) {
                    Toast.makeText(SymptomCollectorActivity.this, "Records Feature", Toast.LENGTH_SHORT).show();
                    return true;
                    // intent = new Intent(getApplicationContext(), RecordsActivity.class);
                } else if (id == R.id.nav_profile) {
                    Toast.makeText(SymptomCollectorActivity.this, "Profile Feature", Toast.LENGTH_SHORT).show();
                    return true;
                    // intent = new Intent(getApplicationContext(), ProfileActivity.class);
                }

                if (intent != null) {
                    startActivity(intent);
                    // Close the current activity to simplify navigation flow
                    finish();
                    return true;
                }

                return false;
            }
        });
    }
    /**
     * Collects symptoms from both checkboxes and free text and applies a combined rule-based triage.
     */
    private void collectAndSortSymptoms() {
        // 1. COLLECT SYMPTOMS

        // Check if any critical symptom is selected (Immediate EMERGENCY)
        boolean hasMcqEmergency = cbChestPain.isChecked() || cbShortnessBreath.isChecked() ||
                cbSevereBleeding.isChecked() || cbLossConsciousness.isChecked();

        // Check if any urgent symptom is selected (Elevated URGENT)
        boolean hasMcqUrgent = cbHighFever.isChecked() || cbFracture.isChecked() || cbPersistentVomiting.isChecked();

        // Get and process free-text symptoms
        String rawSymptoms = symptomInputEditText.getText().toString().trim();
        String processedSymptoms = rawSymptoms.toLowerCase();

        // Check for any input
        if (!hasMcqEmergency && !hasMcqUrgent && rawSymptoms.isEmpty()) {
            Toast.makeText(this, "Please select or enter symptoms to proceed.", Toast.LENGTH_SHORT).show();
            return;
        }

        // 2. SORTING / TRIAGE ALGORITHM (Hierarchical Classification)
        String urgencyLevel;
        int colorResId;
        String recommendation;

        // Rule A: Highest Priority (MCQ Emergency)
        if (hasMcqEmergency) {
            urgencyLevel = "EMERGENCY (Immediate Care Required)";
            colorResId = android.R.color.holo_red_dark;
            recommendation = "The symptoms you described could be serious. Please call for an ambulance or go to the nearest Emergency Department without delay.";
        }
        // Rule B: Second Highest Priority (Free-text Emergency keywords)
        else if (containsKeyword(processedSymptoms, EMERGENCY_KEYWORDS)) {
            urgencyLevel = "EMERGENCY (Immediate Care Required)";
            colorResId = android.R.color.holo_red_dark;
            recommendation = "The symptoms you described could be serious. Please call for an ambulance or go to the nearest Emergency Department without delay.";
        }
        // Rule C: Third Priority (MCQ Urgent or Free-text Urgent keywords)
        else if (hasMcqUrgent || containsKeyword(processedSymptoms, URGENT_KEYWORDS)) {
            urgencyLevel = "URGENT (Prompt Evaluation Needed)";
            colorResId = android.R.color.holo_orange_dark;
            recommendation = "Your symptoms suggest you need prompt medical attention. Please consider visiting an urgent care clinic or contacting your doctor today.";
        }
        // Rule D: Default/Normal
        else {
            urgencyLevel = "NORMAL (Non-Urgent)";
            colorResId = android.R.color.holo_green_dark;
            recommendation = "Your symptoms appear to be non-urgent. We recommend monitoring your condition and booking an appointment with your doctor if they persist or worsen.";
        }

        // 3. DISPLAY RESULT
        displayTriageResult(urgencyLevel, recommendation, colorResId);
    }

    /**
     * Helper method to check if the symptom text contains any of the defined keywords.
     */
    private boolean containsKeyword(String text, Set<String> keywords) {
        // Simple check: iterate through keywords and see if the text contains the whole phrase
        for (String keyword : keywords) {
            if (text.contains(keyword)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Updates the UI to show the determined triage result.
     */
    private void displayTriageResult(String urgency, String recommendation, int colorResId) {
        String resultText = "Urgency Level: " + urgency + "\n\n" + "Next Steps: " + recommendation;

        resultTextView.setText(resultText);
        resultTextView.setTextColor(ContextCompat.getColor(this, colorResId));

        // Set a light background color based on the urgency level
        int backgroundColor = (colorResId == android.R.color.holo_red_dark) ?
                ContextCompat.getColor(this, android.R.color.holo_red_light) :
                (colorResId == android.R.color.holo_orange_dark) ?
                        ContextCompat.getColor(this, android.R.color.holo_orange_light) :
                        ContextCompat.getColor(this, android.R.color.holo_green_light);

        resultTextView.setBackgroundColor(backgroundColor);
        resultTextView.setVisibility(View.VISIBLE);
    }
}
