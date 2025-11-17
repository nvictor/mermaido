//
//  MermaidViewModel.swift
//  Mermaido
//
//  Created by Victor Noagbodji on 11/17/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MermaidViewModel: ObservableObject {
    @Published var mermaidText: String = """
    sequenceDiagram
        Alice->>John: Hello John, how are you?
        John-->>Alice: Great!
        Alice-)John: See you later!
    """
    
    @Published var step: Int = 0
    @Published var renderError: String?
    @Published var isEditing: Bool = false
    @Published var showSequenceNumbers: Bool = true
    @Published var isDarkMode: Bool = false
    
    private var webViewCoordinator: MermaidWebView.Coordinator?
    
    func setWebViewCoordinator(_ coordinator: MermaidWebView.Coordinator) {
        self.webViewCoordinator = coordinator
    }
    

    func goToNextStep() {
        webViewCoordinator?.nextStep()
    }
    
    func goToPreviousStep() {
        webViewCoordinator?.prevStep()
    }
    
    func resetView() {
        webViewCoordinator?.reset()
    }
    
    func toggleEditor() {
        isEditing.toggle()
    }
}
