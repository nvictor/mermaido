//
//  ContentView.swift
//  Mermaido
//
//  Created by Victor Noagbodji on 11/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MermaidViewModel()
    @State private var inspectorPresented = false
    
    var body: some View {
        ZStack {
            MermaidWebView(
                diagramText: $viewModel.mermaidText,
                showSequenceNumbers: viewModel.showSequenceNumbers,
                isDarkMode: viewModel.isDarkMode,
                onRendered: {
                    print("Diagram rendered successfully")
                },
                onError: { error in
                    viewModel.renderError = error
                },
                onLog: { log in
                    print("WebView log: \(log)")
                },
                onStepChanged: { step in
                    viewModel.step = step
                    if step == 0 {
                        viewModel.currentStepInfo = nil
                    }
                },
                onTotalStepsChanged: { total in
                    viewModel.totalSteps = total
                },
                onStepInfo: { from, to, message in
                    viewModel.currentStepInfo = MermaidViewModel.StepInfo(
                        fromActor: from,
                        toActor: to,
                        message: message
                    )
                },
                onCoordinatorReady: { coordinator in
                    viewModel.setWebViewCoordinator(coordinator)
                }
            )
            
            VStack {
                Spacer()
                
                if let stepInfo = viewModel.currentStepInfo {
                    HStack(spacing: 8) {
                        Text(stepInfo.fromActor)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(stepInfo.toActor)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(":")
                            .foregroundColor(.secondary)
                        
                        Text(stepInfo.message)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.bottom, 8)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.goToPreviousStep()
                    }) {
                        Label("Previous", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(viewModel.step == 0)
                    
                    Button(action: {
                        viewModel.goToNextStep()
                    }) {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(viewModel.step >= viewModel.totalSteps)
                    
                    Button(action: {
                        viewModel.resetView()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .labelStyle(.iconOnly)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: {
                        viewModel.toggleEditor()
                    }) {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    
                    Button(action: {
                        inspectorPresented.toggle()
                    }) {
                        Label("Settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 4)
            }
            .padding()
        }
        .inspector(isPresented: $inspectorPresented) {
            DiagramSettingsInspector(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isEditing) {
            DiagramEditorView(viewModel: viewModel)
        }
        .alert("Render Error", isPresented: .constant(viewModel.renderError != nil)) {
            Button("OK") {
                viewModel.renderError = nil
            }
        } message: {
            if let error = viewModel.renderError {
                Text(error)
            }
        }
    }
}

struct DiagramEditorView: View {
    @ObservedObject var viewModel: MermaidViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("Edit Diagram")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            CodeEditorView(text: $viewModel.mermaidText)
                .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct DiagramSettingsInspector: View {
    @ObservedObject var viewModel: MermaidViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagram Settings")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Toggle("Dark Mode", isOn: $viewModel.isDarkMode)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Sequence Diagrams")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Toggle("Show Sequence Numbers", isOn: $viewModel.showSequenceNumbers)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 200)
        .inspectorColumnWidth(min: 200, ideal: 250, max: 300)
    }
}

#Preview {
    ContentView()
}
