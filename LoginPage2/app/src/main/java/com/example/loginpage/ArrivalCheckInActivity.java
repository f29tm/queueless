package com.example.loginpage;
import android.content.Intent;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.cardview.widget.CardView;
import androidx.core.content.ContextCompat;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import java.util.Locale;
import android.content.SharedPreferences;
/**
 * Activity for pre-booked patients to check in upon arrival.
 * Displays appointment details, handles the "I have arrived" click,
 * and shows queue position and pathway guidance.
 */

public class ArrivalCheckInActivity extends AppCompatActivity {

    // UI Components
    private TextView welcomeTextView, doctorNameTextView, timeLocationTextView;
    private Button arrivalCheckInButton;
    private CardView queueStatusCard;
    private TextView queuePositionTextView, pathwayTextView;

    // Mock Data (will be replaced by Firebase/API calls later)

    private static final String MOCK_DOCTOR = "Dr. Meriem Bettayeb (Cardiology)";
    private static final String MOCK_TIME_LOCATION = "Today at 10:30 AM | Clinic 3, 2nd Floor";
    private static final int MOCK_QUEUE_POSITION = 3;
    private static final String MOCK_PATHWAY_GUIDANCE = "Proceed directly to Clinic 3, 2nd Floor.";


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_arrival_checkin);

        // Initialize UI components for the main content
        welcomeTextView = findViewById(R.id.welcomeTextView);
        doctorNameTextView = findViewById(R.id.doctorNameTextView);
        timeLocationTextView = findViewById(R.id.timeLocationTextView);
        arrivalCheckInButton = findViewById(R.id.arrivalCheckInButton);
        queueStatusCard = findViewById(R.id.queueStatusCard);
        queuePositionTextView = findViewById(R.id.queuePositionTextView);
        pathwayTextView = findViewById(R.id.pathwayTextView);

        // Load initial mock data
        loadAppointmentDetails();

        // Set up button click listener
        arrivalCheckInButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                handleCheckIn();
            }
        });

        // Initialize and set up the Bottom Navigation Bar
        setupBottomNavigation();
    }

    /**
     * Initializes the Bottom Navigation View and sets up the item selection listener
     * for consistent app-wide navigation.
     */
    private void setupBottomNavigation() {
        BottomNavigationView bottomNavigationView = findViewById(R.id.bottom_navigation_bar);

        // Highlight the current tab: Home (since Check-in is part of the main Hub flow)
        bottomNavigationView.setSelectedItemId(R.id.nav_home);

        bottomNavigationView.setOnItemSelectedListener(new BottomNavigationView.OnItemSelectedListener() {
            @Override
            public boolean onNavigationItemSelected(@NonNull MenuItem item) {
                int id = item.getItemId();
                Intent intent = null;

                if (id == R.id.nav_home) {
                    intent = new Intent(getApplicationContext(), PatientHubActivity.class);
                } else if (id == R.id.nav_chatbot) {
                    Toast.makeText(ArrivalCheckInActivity.this, "Chatbot Feature", Toast.LENGTH_SHORT).show();
                    return true;
                    // intent = new Intent(getApplicationContext(), ChatbotActivity.class);
                } else if (id == R.id.nav_records) {
                    Toast.makeText(ArrivalCheckInActivity.this, "Records Feature", Toast.LENGTH_SHORT).show();
                    return true;
                    // intent = new Intent(getApplicationContext(), RecordsActivity.class);
                } else if (id == R.id.nav_profile) {
                    Toast.makeText(ArrivalCheckInActivity.this, "Profile Feature", Toast.LENGTH_SHORT).show();
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
     * Simulates fetching the patient's next appointment details from a database.
     */
    private void loadAppointmentDetails() {

        SharedPreferences prefs = getSharedPreferences("UserData", MODE_PRIVATE);
        String name = prefs.getString("patient_name", "Patient");

        welcomeTextView.setText(String.format("Welcome, %s!", name));

        doctorNameTextView.setText(MOCK_DOCTOR);
        timeLocationTextView.setText(MOCK_TIME_LOCATION);
    }


    /**
     * Handles the "I Have Arrived" button click.
     * 1. Notifies the hospital system (simulated).
     * 2. Retrieves/Calculates queue status (simulated).
     * 3. Updates the UI.
     */
    private void handleCheckIn() {
        // --- 1. Notify Hospital System (Simulated) ---
        Toast.makeText(this, "Check-In Signal Sent to Hospital System.", Toast.LENGTH_SHORT).show();

        // Disable button after check-in
        arrivalCheckInButton.setText("CHECKED IN");
        arrivalCheckInButton.setBackgroundColor(ContextCompat.getColor(this, android.R.color.darker_gray));
        arrivalCheckInButton.setEnabled(false);

        // --- 2. Update Queue Status and Pathway ---
        String positionText = String.format(Locale.getDefault(), "You are currently: %d%s in line.",
                MOCK_QUEUE_POSITION, getOrdinal(MOCK_QUEUE_POSITION));

        queuePositionTextView.setText(positionText);
        pathwayTextView.setText(String.format(Locale.getDefault(), "Pathway: %s", MOCK_PATHWAY_GUIDANCE));

        // Show the status card
        queueStatusCard.setVisibility(View.VISIBLE);
    }

    /**
     * Helper function to get the correct ordinal suffix (1st, 2nd, 3rd, 4th, etc.).
     */
    private String getOrdinal(int n) {
        if (n >= 11 && n <= 13) {
            return "th";
        }
        switch (n % 10) {
            case 1:  return "st";
            case 2:  return "nd";
            case 3:  return "rd";
            default: return "th";
        }
    }
}