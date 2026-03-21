package com.example.loginpage;

import android.content.Intent;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.cardview.widget.CardView;

import com.google.android.material.bottomnavigation.BottomNavigationView;

public class StaffHubActivity extends AppCompatActivity {

    private CardView cardStaffDashboard, cardPatientRecords;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_staff_hub);

        // Initialize the cards
        cardStaffDashboard = findViewById(R.id.card_staff_dashboard);
        cardPatientRecords = findViewById(R.id.card_patient_records);

        // Set click listeners for the cards
        cardStaffDashboard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(getApplicationContext(), StaffDashboardActivity.class);
                startActivity(intent);
            }
        });

        cardPatientRecords.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showNotImplementedToast();
            }
        });

        // Set up the bottom navigation
        setupBottomNavigation();
    }

    private void setupBottomNavigation() {
        BottomNavigationView bottomNavigationView = findViewById(R.id.staff_bottom_navigation_bar);
        bottomNavigationView.setOnItemSelectedListener(new BottomNavigationView.OnItemSelectedListener() {
            @Override
            public boolean onNavigationItemSelected(@NonNull MenuItem item) {
                int id = item.getItemId();

                if (id == R.id.nav_staff_home) {
                    // Already on the main hub, do nothing
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
}

