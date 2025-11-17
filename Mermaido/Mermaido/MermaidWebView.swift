//
//  MermaidWebView.swift
//  Mermaido
//
//  Created by Victor Noagbodji on 11/17/25.
//

import SwiftUI
import WebKit

struct MermaidWebView: NSViewRepresentable {
    @Binding var diagramText: String
    var showSequenceNumbers: Bool
    var isDarkMode: Bool
    var onRendered: (() -> Void)?
    var onError: ((String) -> Void)?
    var onLog: ((String) -> Void)?
    var onStepChanged: ((Int) -> Void)?
    var onTotalStepsChanged: ((Int) -> Void)?
    var onCoordinatorReady: ((Coordinator) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "onRendered")
        userContentController.add(context.coordinator, name: "onError")
        userContentController.add(context.coordinator, name: "onLog")
        userContentController.add(context.coordinator, name: "stepChanged")
        userContentController.add(context.coordinator, name: "totalStepsChanged")
        
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.parent = self
        
        // Notify that coordinator is ready
        onCoordinatorReady?(context.coordinator)
        
        loadHTML(webView: webView)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Check if settings have changed
        let settingsChanged = context.coordinator.showSequenceNumbers != showSequenceNumbers ||
                            context.coordinator.isDarkMode != isDarkMode
        
        if settingsChanged {
            context.coordinator.showSequenceNumbers = showSequenceNumbers
            context.coordinator.isDarkMode = isDarkMode
            updateMermaidConfig(webView: webView)
        }
        
        // Store the diagram text and render if mermaid is ready
        if diagramText != context.coordinator.pendingDiagramText {
            context.coordinator.pendingDiagramText = diagramText
            
            // If page is loaded and mermaid is ready, render immediately
            if context.coordinator.pageLoaded && !diagramText.isEmpty {
                // Check if mermaid is ready and render
                let checkReady = "typeof window.mermaidReady !== 'undefined' && window.mermaidReady"
                webView.evaluateJavaScript(checkReady) { result, error in
                    if let isReady = result as? Bool, isReady {
                        if diagramText != context.coordinator.lastDiagramText {
                            context.coordinator.lastDiagramText = diagramText
                            self.setDiagram(webView: webView, text: diagramText)
                        }
                    }
                }
            }
        }
    }
    
    private func loadHTML(webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Mermaid Viewer</title>
            <script type="module">
                import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
                import panzoom from 'https://cdn.jsdelivr.net/npm/panzoom@9.4.3/+esm';
                
                mermaid.initialize({ 
                    startOnLoad: false,
                    theme: 'default',
                    securityLevel: 'loose',
                    logLevel: 'debug',
                    sequence: {
                        showSequenceNumbers: true
                    }
                });
                
                window.mermaid = mermaid;
                window.currentStep = 0;
                window.mermaidReady = true;
                window.currentDiagramType = null;
                window.panInstance = null;
                window.sequenceElements = [];
                
                window.renderDiagram = async function(diagramText) {
                    try {
                        const container = document.getElementById('mermaid-container');
                        
                        if (window.panInstance) {
                            window.panInstance.dispose();
                            window.panInstance = null;
                        }
                        
                        container.innerHTML = '';
                        
                        const { svg } = await mermaid.render('mermaid-diagram', diagramText);
                        container.innerHTML = svg;
                        
                        window.currentDiagramType = detectDiagramType(diagramText);
                        
                        try {
                            const svgElement = container.querySelector('svg');
                            if (svgElement) {
                                window.panInstance = panzoom(svgElement, {
                                    maxZoom: 10,
                                    minZoom: 0.1,
                                    bounds: false,
                                    boundsPadding: 0.1,
                                    zoomDoubleClickSpeed: 1
                                });
                            }
                        } catch (panzoomError) {
                            window.webkit.messageHandlers.onError.postMessage('Panzoom error: ' + panzoomError.toString());
                        }
                        
                        if (window.currentDiagramType === 'sequence') {
                           setTimeout(setupSequenceStepping, 200); // Allow SVG to render
                        }
                        
                        window.webkit.messageHandlers.onRendered.postMessage({});
                        
                        window.currentStep = 0;
                        window.webkit.messageHandlers.stepChanged.postMessage(0);
                    } catch (error) {
                        window.webkit.messageHandlers.onError.postMessage(error.toString());
                    }
                };
                
                function detectDiagramType(text) {
                    if (text.trim().startsWith('sequenceDiagram')) return 'sequence';
                    return 'unknown';
                }
                
                function setupSequenceStepping() {
                    const sequenceNumbers = Array.from(document.querySelectorAll('.sequenceNumber'));
                    
                    window.sequenceElements = sequenceNumbers
                        .map(e => ({
                            number: parseInt(e.textContent, 10),
                            element: e
                        }))
                        .sort((a, b) => a.number - b.number);
                    
                    window.webkit.messageHandlers.totalStepsChanged.postMessage(window.sequenceElements.length);
                }
                
                function panToStep(stepNumber) {
                    if (!window.panInstance || !window.sequenceElements) return;

                    const targetElement = window.sequenceElements.find(e => e.number === stepNumber);
                    if (!targetElement) return;

                    const rect = targetElement.element.getBoundingClientRect();
                    
                    // Simplified padding from mermaid-viewer
                    const padding = 200;

                    if(window.panInstance.smoothShowRectangle) {
                         window.panInstance.smoothShowRectangle({
                            ...rect.toJSON(),
                            left: rect.left - padding,
                            top: rect.top - padding,
                            right: rect.right + padding,
                            bottom: rect.bottom + padding
                        });
                    } else {
                        // Fallback pan logic
                        const svg = document.querySelector('#mermaid-container svg');
                        if(svg) {
                            const svgRect = svg.getBoundingClientRect();
                            const relativeX = rect.left - svgRect.left + rect.width / 2;
                            const relativeY = rect.top - svgRect.top + rect.height / 2;
                            window.panInstance.smoothMoveTo(
                                svgRect.width / 2 - relativeX,
                                svgRect.height / 2 - relativeY
                            );
                        }
                    }
                   
                }

                window.nextStep = function() {
                    if (window.currentDiagramType !== 'sequence' || !window.sequenceElements) return;
                    
                    const nextStep = window.currentStep + 1;
                    if (nextStep <= window.sequenceElements.length) {
                        window.currentStep = nextStep;
                        panToStep(window.currentStep);
                        window.webkit.messageHandlers.stepChanged.postMessage(window.currentStep);
                    }
                };

                window.prevStep = function() {
                    if (window.currentDiagramType !== 'sequence' || !window.sequenceElements) return;

                    if (window.currentStep > 1) {
                        window.currentStep--;
                        panToStep(window.currentStep);
                    } else {
                        window.currentStep = 0;
                        window.reset();
                    }
                    window.webkit.messageHandlers.stepChanged.postMessage(window.currentStep);
                };

                window.reset = function() {
                    window.currentStep = 0;
                    if (window.panInstance) {
                        window.panInstance.smoothZoomAbs(0, 0, 1);
                        window.panInstance.moveTo(0, 0);
                    }
                    window.webkit.messageHandlers.stepChanged.postMessage(0);
                };
                
                // Signal that mermaid is loaded and ready
                window.webkit.messageHandlers.onLog.postMessage('Mermaid module loaded and ready');
            </script>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    width: 100%;
                    height: 100vh;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    background: #ffffff;
                    overflow: auto;
                    transition: background-color 0.3s ease;
                }
                #mermaid-container {
                    width: 100%;
                    height: 100%;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    padding: 20px;
                }
                #mermaid-container svg {
                    max-width: 100%;
                    height: auto;
                }
            </style>
        </head>
        <body>
            <div id="mermaid-container"></div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func updateMermaidConfig(webView: WKWebView) {
        let theme = isDarkMode ? "dark" : "default"
        let backgroundColor = isDarkMode ? "#1e1e1e" : "#ffffff"
        let showNumbers = showSequenceNumbers ? "true" : "false"
        
        let updateScript = """
        (function() {
            if (window.mermaid) {
                window.mermaid.initialize({
                    startOnLoad: false,
                    theme: '\(theme)',
                    securityLevel: 'loose',
                    logLevel: 'debug',
                    sequence: {
                        showSequenceNumbers: \(showNumbers)
                    }
                });
                
                document.body.style.backgroundColor = '\(backgroundColor)';
                
                // Re-render if there's a diagram
                if (window.currentDiagramType) {
                    const container = document.getElementById('mermaid-container');
                    const diagramText = container.getAttribute('data-diagram-text');
                    if (diagramText) {
                        window.renderDiagram(diagramText);
                    }
                }
            }
        })();
        """
        
        webView.evaluateJavaScript(updateScript) { _, error in
            if let error = error {
                self.onError?("Failed to update config: \(error.localizedDescription)")
            }
        }
    }
    
    private func setDiagram(webView: WKWebView, text: String) {
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        // Store the diagram text in the container for re-rendering
        let storeAndRender = """
        (function() {
            const container = document.getElementById('mermaid-container');
            container.setAttribute('data-diagram-text', `\(escapedText)`);
            
            if (typeof renderDiagram === 'function' && window.mermaidReady) {
                renderDiagram(`\(escapedText)`);
                return 'rendering';
            } else {
                return 'not ready - renderDiagram: ' + (typeof renderDiagram) + ', mermaidReady: ' + window.mermaidReady;
            }
        })()
        """
        
        webView.evaluateJavaScript(storeAndRender) { result, error in
            if let error = error {
                self.onError?("Failed to render diagram: \(error.localizedDescription)")
            }
        }
    }
    
    func nextStep(webView: WKWebView) {
        webView.evaluateJavaScript("if (typeof nextStep === 'function') { nextStep(); }") { _, error in
            if let error = error {
                onError?("Failed to go to next step: \(error.localizedDescription)")
            }
        }
    }
    
    func prevStep(webView: WKWebView) {
        webView.evaluateJavaScript("if (typeof prevStep === 'function') { prevStep(); }") { _, error in
            if let error = error {
                onError?("Failed to go to previous step: \(error.localizedDescription)")
            }
        }
    }
    
    func reset(webView: WKWebView) {
        webView.evaluateJavaScript("if (typeof reset === 'function') { reset(); }") { _, error in
            if let error = error {
                onError?("Failed to reset: \(error.localizedDescription)")
            }
        }
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: MermaidWebView
        weak var webView: WKWebView?
        var lastDiagramText: String = ""
        var pendingDiagramText: String = ""
        var pageLoaded: Bool = false
        var showSequenceNumbers: Bool = true
        var isDarkMode: Bool = false
        
        init(_ parent: MermaidWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
            parent.onLog?("Page loaded, waiting for mermaid module...")
            
            // Don't render yet - wait for the module to signal it's ready
            // The module will post a message when ready, and we'll check pendingDiagramText then
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "onRendered":
                parent.onRendered?()
            case "onError":
                if let errorMessage = message.body as? String {
                    parent.onError?(errorMessage)
                }
            case "onLog":
                if let logMessage = message.body as? String {
                    parent.onLog?(logMessage)
                    
                    // If mermaid just loaded, render the pending diagram
                    if logMessage.contains("Mermaid module loaded and ready") {
                        if !pendingDiagramText.isEmpty && pendingDiagramText != lastDiagramText {
                            lastDiagramText = pendingDiagramText
                            if let webView = webView {
                                parent.setDiagram(webView: webView, text: pendingDiagramText)
                            }
                        }
                    }
                }
            case "stepChanged":
                if let step = message.body as? Int {
                    parent.onStepChanged?(step)
                }
            case "totalStepsChanged":
                if let total = message.body as? Int {
                    parent.onTotalStepsChanged?(total)
                }
            default:
                break
            }
        }
        
        func nextStep() {
            if let webView = webView {
                parent.nextStep(webView: webView)
            }
        }
        
        func prevStep() {
            if let webView = webView {
                parent.prevStep(webView: webView)
            }
        }
        
        func reset() {
            if let webView = webView {
                parent.reset(webView: webView)
            }
        }
    }
}
