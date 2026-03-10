//
//  XboxStatusView.swift
//  CatFollowerApp
//
//  Created by rlush on 2/21/26.
//

import SwiftUI

struct XboxStatusView: View {
    @ObservedObject var viewModel: RobotViewModel
    
    var body: some View {
        GroupBox(label: Label("Xbox Controller", systemImage: "gamecontroller.fill")) {
            VStack(spacing: 16) {
                // Joystick visualization
                HStack(spacing: 40) {
                    JoystickView(
                        title: "Left Stick",
                        xValue: 0.0, // TODO: Add to telemetry
                        yValue: 0.0
                    )
                }
                
                // Buttons
                HStack(spacing: 20) {
                    ButtonIndicator(label: "A", active: false, color: .green)
                    ButtonIndicator(label: "B", active: false, color: .red)
                    ButtonIndicator(label: "Start", active: false, color: .orange)
                }
                
                Text("Controller telemetry coming soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

struct JoystickView: View {
    let title: String
    let xValue: Float
    let yValue: Float
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .offset(
                        x: CGFloat(xValue) * 40,
                        y: CGFloat(-yValue) * 40
                    )
            }
            
            HStack(spacing: 12) {
                VStack {
                    Text("X")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", xValue))
                        .font(.caption)
                        .monospacedDigit()
                }
                
                VStack {
                    Text("Y")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f", yValue))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }
}

struct ButtonIndicator: View {
    let label: String
    let active: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(active ? color : Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(label)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                )
            
            Text(active ? "ON" : "OFF")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    XboxStatusView(viewModel: RobotViewModel())
        .padding()
}
