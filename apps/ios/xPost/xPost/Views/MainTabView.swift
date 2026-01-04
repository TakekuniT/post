//
//  MainTabView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Tab 1: Dashboard/Feed
            MainDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // Tab 2: Upload
            UploadView()
                .tabItem {
                    Label("Upload", systemImage: "plus.circle.fill")
                }

            // Tab 3: Account
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
    }
}
