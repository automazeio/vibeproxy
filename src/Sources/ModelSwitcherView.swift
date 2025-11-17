import SwiftUI

struct ModelSwitcherView: View {
    @ObservedObject var modelSwitcher: ModelSwitcher
    @State private var expandedService: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Model Switcher")
                    .font(.headline)
                Spacer()
                Text("Current: \(modelSwitcher.selectedModel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(Array(modelSwitcher.getModelsGroupedByService().sorted { $0.key < $1.key }), id: \.key) { service, models in
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: {
                            withAnimation {
                                if expandedService == service {
                                    expandedService = nil
                                } else {
                                    expandedService = service
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: expandedService == service ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                Text(service)
                                    .font(.headline)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)

                        if expandedService == service {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(models, id: \.self) { model in
                                    Button(action: {
                                        modelSwitcher.selectedModel = model
                                        modelSwitcher.saveSelectedModel()
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(model)
                                                    .font(.system(.body, design: .monospaced))
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            if modelSwitcher.selectedModel == model {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(modelSwitcher.selectedModel == model ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(6)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// Menu bar model switcher component
struct MenuBarModelSwitcher: NSView {
    let modelSwitcher: ModelSwitcher
    var onModelChanged: (() -> Void)?

    let button = NSButton()
    let menu = NSMenu()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
        setupMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupButton() {
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .texturedRounded
        button.font = NSFont.systemFont(ofSize: 11)
        button.target = self
        button.action = #selector(showMenu)
        updateButtonTitle()

        addSubview(button)
        button.frame = self.bounds
    }

    private func setupMenu() {
        let allModels = modelSwitcher.getModelsGroupedByService()

        for (service, models) in allModels.sorted(by: { $0.key < $1.key }) {
            if !menu.items.isEmpty {
                menu.addItem(NSMenuItem.separator())
            }

            let serviceItem = NSMenuItem(title: service, action: nil, keyEquivalent: "")
            serviceItem.isEnabled = false
            menu.addItem(serviceItem)

            for model in models {
                let item = NSMenuItem(
                    title: model,
                    action: #selector(selectModel(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = model
                item.target = self

                if modelSwitcher.selectedModel == model {
                    item.state = .on
                }

                menu.addItem(item)
            }
        }
    }

    @objc private func showMenu() {
        menu.popUp(positioning: nil, at: button.frame.origin, in: self)
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? String else { return }
        modelSwitcher.selectedModel = model
        modelSwitcher.saveSelectedModel()
        updateButtonTitle()
        onModelChanged?()
    }

    private func updateButtonTitle() {
        let displayModel = modelSwitcher.selectedModel.count > 20
            ? String(modelSwitcher.selectedModel.prefix(17)) + "..."
            : modelSwitcher.selectedModel
        button.title = "Model: \(displayModel)"
    }
}

// SwiftUI wrapper for menu bar component
struct MenuBarModelSwitcherView: NSViewRepresentable {
    let modelSwitcher: ModelSwitcher
    var onModelChanged: (() -> Void)?

    func makeNSView(context: Context) -> MenuBarModelSwitcher {
        let view = MenuBarModelSwitcher()
        view.modelSwitcher = modelSwitcher
        view.onModelChanged = onModelChanged
        return view
    }

    func updateNSView(_ nsView: MenuBarModelSwitcher, context: Context) {
        // Update as needed
    }
}
