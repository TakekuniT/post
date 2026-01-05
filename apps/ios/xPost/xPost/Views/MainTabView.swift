//
//  MainTabView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/3/26.
//

import SwiftUI

// 1. ENSURE THIS IS OUTSIDE THE STRUCT
enum Tab: String, CaseIterable {
    case home = "house.fill"
    case upload = "plus.viewfinder"
    case account = "person.fill"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .upload: return "Upload"
        case .account: return "Account"
        }
    }
}

struct MainTabView: View {
    @State private var activeTab: Tab = .home // This should work now
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content Area
            renderCurrentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: activeTab)

            // Classic Pinned Tab Bar
            VStack(spacing: 0) {
                Divider()
                    .background(Color.brandPurple.opacity(0.1))
                
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                activeTab = tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                // Indicator bar
                                ZStack {
                                    if activeTab == tab {
                                        Rectangle()
                                            .fill(Color.brandPurple)
                                            .frame(width: 40, height: 3)
                                            .cornerRadius(10)
                                            .matchedGeometryEffect(id: "INDICATOR", in: animation)
                                    } else {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(width: 40, height: 3)
                                    }
                                }
                                .padding(.bottom, 4)

                                Image(systemName: tab.rawValue)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(activeTab == tab ? .brandPurple : .secondary)
                                
                                Text(tab.title)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(activeTab == tab ? .brandPurple : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial)
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // 2. HELPER TO FIX GENERIC PARAMETER ERROR
    @ViewBuilder
    private func renderCurrentView() -> some View {
        switch activeTab {
        case .home:
            MainDashboardView()
        case .upload:
            UploadView()
        case .account:
            AccountView()
        }
    }
}
