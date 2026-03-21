package com.example.loginpage;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.cardview.widget.CardView;

import com.google.android.material.bottomnavigation.BottomNavigationView;

/**
 * Main dashboard (Hub) for the patient.
 */
public class PatientHubActivity extends AppCompatActivity {

    private CardView cardCheckIn;
    private CardView cardSymptomTriage;
    private BottomNavigationView bottomNavigationView;

    private TextView tvWelcome;   // <-- NEW: Welcome message

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_patient_hub);

        // Initialize Views
        cardCheckIn = findViewById(R.id.card_check_in);
        cardSymptomTriage = findViewById(R.id.card_symptom_triage);
        bottomNavigationView = findViewById(R.id.bottom_navigation_bar);
        tvWelcome = findViewById(R.id.tvWelcomePatient);  // <-- ADD THIS IN XML

        // Display Welcome Message
        loadWelcomeMessage();

        // Setup Listeners
        setupCardListeners();
        setupBottomNavigation();
    }

    /**
     * Load patient name from SharedPreferences and display it at the top.
     */
    private void loadWelcomeMessage() {
        SharedPreferences prefs = getSharedPreferences("UserData", MODE_PRIVATE);
        String name = prefs.getString("patient_name", null);

        if (name != null && !name.trim().isEmpty()) {
            tvWelcome.setText("Welcome, " + name);
        } else {
            tvWelcome.setText("Welcome!");
        }
    }

    /**
     * Card actions
     */
    private void setupCardListeners() {

        cardCheckIn.setOnClickListener(v -> {
            Intent intent = new Intent(PatientHubActivity.this, ArrivalCheckInActivity.class);
            startActivity(intent);
        });

        cardSymptomTriage.setOnClickListener(v -> {
            Intent intent = new Intent(PatientHubActivity.this, SymptomCollectorActivity.class);
            startActivity(intent);
        });
    }

    /**
     * Bottom navigation handling
     */
    private void setupBottomNavigation() {

        bottomNavigationView.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            Intent intent = null;

            if (id == R.id.nav_home) {
                return true;

            } else if (id == R.id.nav_chatbot) {
                Toast.makeText(PatientHubActivity.this, "Chatbot Feature Coming Soon", Toast.LENGTH_SHORT).show();
                return true;

            } else if (id == R.id.nav_records) {
                Toast.makeText(PatientHubActivity.this, "Opening Records", Toast.LENGTH_SHORT).show();
                // intent = new Intent(this, RecordsActivity.class);

            } else if (id == R.id.nav_profile) {
                Toast.makeText(PatientHubActivity.this, "Opening Profile", Toast.LENGTH_SHORT).show();
                // intent = new Intent(this, ProfileActivity.class);
            }

            if (intent != null) {
                startActivity(intent);
                return true;
            }
            return false;
        });
    }
}
