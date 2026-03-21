package com.example.loginpage;

import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.bottomnavigation.BottomNavigationView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

/**
 * Activity for the Staff Dashboard, demonstrating the real-time queue view.
 * Simulates fetching triaged patients and sorting them by urgency level.
 */
public class StaffDashboardActivity extends AppCompatActivity {

    private TextView statusSummaryTextView;
    private ListView patientListView;
    private List<PatientQueueEntry> patientList;

    // --- Mock Data Structure ---
    public static class PatientQueueEntry {
        String name;
        String symptoms;
        String urgencyLevel; // e.g., "EMERGENCY", "URGENT", "NORMAL"
        String checkInTime;

        public PatientQueueEntry(String name, String symptoms, String urgencyLevel, String checkInTime) {
            this.name = name;
            this.symptoms = symptoms;
            this.urgencyLevel = urgencyLevel;
            this.checkInTime = checkInTime;
        }
    }
    // --- End Mock Data Structure ---

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_staff_dashboard);

        statusSummaryTextView = findViewById(R.id.statusSummaryTextView);
        patientListView = findViewById(R.id.patientListView);

        // 1. Simulate data fetching
        loadMockPatientData();

        // 2. Sort patients by urgency (EMERGENCY > URGENT > NORMAL)
        sortPatientQueue();

        // 3. Update Summary and Display List
        updateSummary();
        displayQueueList();

        // 4. Set up the bottom navigation
        setupBottomNavigation();
    }

    /**
     * Simulates fetching patient records, including their triaged urgency level.
     */
    private void loadMockPatientData() {
        patientList = new ArrayList<>();
        // Note the different urgency levels being assigned here, simulating the triage engine

        // EMERGENCY Cases (Highest Priority)
        patientList.add(new PatientQueueEntry("Khalid Al Marzouqi", "Severe chest pain (MCQ selected)", "EMERGENCY", "10:01 AM"));

        // URGENT Cases
        patientList.add(new PatientQueueEntry("Fatima Ahmed", "Broken finger (Typing matched 'broken bone')", "URGENT", "09:55 AM"));
        patientList.add(new PatientQueueEntry("Yousef Ali", "Persistent vomiting, high fever (MCQ selected)", "URGENT", "10:15 AM"));

        // NORMAL Cases (Lowest Priority)
        patientList.add(new PatientQueueEntry("Aisha Mansour", "Minor headache, sore throat", "NORMAL", "09:45 AM"));
        patientList.add(new PatientQueueEntry("Hassan Saeed", "Follow-up appointment, no new symptoms", "NORMAL", "10:20 AM"));
    }

    /**
     * Sorts the patient list based on urgency level, ensuring the most critical patients are first.
     * This is the core logic of the Intelligent Queue Management component.
     */
    private void sortPatientQueue() {
        // Custom Comparator to define the priority order
        Collections.sort(patientList, new Comparator<PatientQueueEntry>() {
            @Override
            public int compare(PatientQueueEntry p1, PatientQueueEntry p2) {
                // Assign a numeric value to urgency for easy comparison
                int rank1 = getUrgencyRank(p1.urgencyLevel);
                int rank2 = getUrgencyRank(p2.urgencyLevel);

                // Sort descending (higher rank/urgency comes first)
                if (rank1 != rank2) {
                    return Integer.compare(rank2, rank1);
                } else {
                    // Secondary sorting: Sort by check-in time (oldest first) for same urgency
                    return p1.checkInTime.compareTo(p2.checkInTime);
                }
            }
        });
    }

    /**
     * Helper to convert urgency string to a comparable integer rank.
     * EMERGENCY (3) > URGENT (2) > NORMAL (1)
     */
    private int getUrgencyRank(String urgency) {
        switch (urgency.toUpperCase(Locale.ROOT)) {
            case "EMERGENCY":
                return 3;
            case "URGENT":
                return 2;
            case "NORMAL":
                return 1;
            default:
                return 0;
        }
    }

    /**
     * Updates the text summary at the top of the dashboard.
     */
    private void updateSummary() {
        long total = patientList.size();
        long emergencies = patientList.stream().filter(p -> p.urgencyLevel.equals("EMERGENCY")).count();

        statusSummaryTextView.setText(String.format(Locale.getDefault(),
                "Total Patients Waiting: %d | Emergencies: %d", total, emergencies));
    }

    /**
     * Sets the custom adapter to display the sorted patient list in the ListView.
     */
    private void displayQueueList() {
        PatientAdapter adapter = new PatientAdapter(this, patientList);
        patientListView.setAdapter(adapter);
    }

    private void setupBottomNavigation() {
        BottomNavigationView bottomNavigationView = findViewById(R.id.staff_bottom_navigation_bar);
        bottomNavigationView.setOnItemSelectedListener(new BottomNavigationView.OnItemSelectedListener() {
            @Override
            public boolean onNavigationItemSelected(@NonNull MenuItem item) {
                int id = item.getItemId();

                if (id == R.id.nav_staff_home) {
                    Intent intent = new Intent(getApplicationContext(), StaffHubActivity.class);
                    startActivity(intent);
                    finish(); // Close the dashboard to go back to the hub
                    return true;
                } else if (id == R.id.nav_staff_patients) {
                    showNotImplementedToast();
                    return true;
                } else if (id == R.id.nav_staff_alerts) {
                    showNotImplementedToast();
                    return true;
                } else if (id == R.id.nav_staff_profile) {
                    showNotImplementedToast();
                    return true;
                }

                return false;
            }
        });
    }

    private void showNotImplementedToast() {
        Toast.makeText(this, "Feature not implemented", Toast.LENGTH_SHORT).show();
    }

    // --- Custom Adapter for ListView ---
    private class PatientAdapter extends ArrayAdapter<PatientQueueEntry> {
        private final Context context;
        private final List<PatientQueueEntry> patients;

        public PatientAdapter(Context context, List<PatientQueueEntry> patients) {
            super(context, R.layout.list_item_patient, patients);
            this.context = context;
            this.patients = patients;
        }

        @NonNull
        @Override
        public View getView(int position, @Nullable View convertView, @NonNull ViewGroup parent) {
            LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            View rowView = inflater.inflate(R.layout.list_item_patient, parent, false);

            PatientQueueEntry patient = patients.get(position);

            TextView nameView = rowView.findViewById(R.id.patientNameTextView);
            TextView urgencyView = rowView.findViewById(R.id.patientUrgencyTextView);
            TextView symptomView = rowView.findViewById(R.id.patientSymptomsTextView);

            nameView.setText(patient.name);
            urgencyView.setText(patient.urgencyLevel);
            symptomView.setText(String.format(Locale.getDefault(), "Symptoms: %s", patient.symptoms));

            // Set background/text color based on urgency for quick visual identification
            if (patient.urgencyLevel.equals("EMERGENCY")) {
                urgencyView.setTextColor(Color.WHITE);
                urgencyView.setBackgroundColor(Color.RED);
            } else if (patient.urgencyLevel.equals("URGENT")) {
                urgencyView.setTextColor(Color.WHITE);
                urgencyView.setBackgroundColor(Color.parseColor("#FFA500")); // Orange
            } else {
                urgencyView.setTextColor(Color.DKGRAY);
                urgencyView.setBackgroundColor(Color.LTGRAY);
            }

            return rowView;
        }
    }
    // --- End Custom Adapter ---
}