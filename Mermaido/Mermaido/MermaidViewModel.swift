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
        participant User
        participant Frontend
        participant API
        participant AuthService
        participant Database
        participant Cache
        participant EmailService
        
        User->>Frontend: Login request
        Frontend->>API: POST /auth/login
        API->>AuthService: Validate credentials
        AuthService->>Database: Query user table
        Database-->>AuthService: User record
        AuthService->>Database: Check password hash
        Database-->>AuthService: Hash verified
        AuthService->>Cache: Store session token
        Cache-->>AuthService: Token stored
        AuthService-->>API: Authentication successful
        API-->>Frontend: Return JWT token
        Frontend-->>User: Redirect to dashboard
        
        User->>Frontend: Request user profile
        Frontend->>API: GET /user/profile
        API->>AuthService: Validate JWT
        AuthService->>Cache: Check token
        Cache-->>AuthService: Token valid
        AuthService-->>API: User authenticated
        API->>Database: Fetch user profile
        Database-->>API: Profile data
        API-->>Frontend: Return profile
        Frontend-->>User: Display profile
        
        User->>Frontend: Update email
        Frontend->>API: PUT /user/email
        API->>AuthService: Validate JWT
        AuthService->>Cache: Check token
        Cache-->>AuthService: Token valid
        AuthService-->>API: User authenticated
        API->>Database: Update email
        Database-->>API: Email updated
        API->>EmailService: Send verification email
        EmailService-->>API: Email sent
        API-->>Frontend: Update successful
        Frontend-->>User: Show confirmation
    """
    
    @Published var step: Int = 0
    @Published var totalSteps: Int = 0
    @Published var renderError: String?
    @Published var isEditing: Bool = false
    @Published var showSequenceNumbers: Bool = true
    @Published var isDarkMode: Bool = false
    @Published var currentStepInfo: StepInfo?
    
    private var webViewCoordinator: MermaidWebView.Coordinator?
    
    struct StepInfo: Equatable {
        let fromActor: String
        let toActor: String
        let message: String
    }
    
    func setWebViewCoordinator(_ coordinator: MermaidWebView.Coordinator) {
        self.webViewCoordinator = coordinator
    }
    

    func goToNextStep() {
        print("ViewModel: goToNextStep called, current step: \(step)")
        webViewCoordinator?.nextStep()
    }
    
    func goToPreviousStep() {
        print("ViewModel: goToPreviousStep called, current step: \(step)")
        webViewCoordinator?.prevStep()
    }
    
    func resetView() {
        print("ViewModel: resetView called")
        webViewCoordinator?.reset()
    }
    
    func toggleEditor() {
        isEditing.toggle()
    }
}
