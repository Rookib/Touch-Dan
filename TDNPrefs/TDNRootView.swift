import Combine
import MCEmojiPicker
import SwiftUI

struct TDNRootView: View {

    @AppStorage("isEnabled", store: TDNUserDefaults.standard)
    var isEnabled = false

    @AppStorage("isRecordingOnly", store: TDNUserDefaults.standard)
    var isRecordingOnly = false

    @AppStorage("useTrackingEffect", store: TDNUserDefaults.standard)
    var useTrackingEffect = false

    @AppStorage("useMorphEffect", store: TDNUserDefaults.standard)
    var useMorphEffect = false

    @AppStorage("useImageEffect", store: TDNUserDefaults.standard)
    var useImageEffect = false

    @AppStorage("useQuickPathEffect", store: TDNUserDefaults.standard)
    var useQuickPathEffect = false

    @AppStorage("fillColorString", store: TDNUserDefaults.standard)
    var fillColorString: String = "13,148,136,0.3"
    @State var fillColor: Color = .clear

    @AppStorage("borderColorString", store: TDNUserDefaults.standard)
    var borderColorString: String = "13,148,136"
    @State var borderColor: Color = .clear

    @AppStorage("quickPathFillColorString", store: TDNUserDefaults.standard)
    var quickPathFillColorString: String = "13,148,136,0.3"
    @State var quickPathFillColor: Color = .clear

    @AppStorage("trackingFillColorString", store: TDNUserDefaults.standard)
    var trackingFillColorString: String = "13,148,136,0.12"
    @State var trackingFillColor: Color = .clear

    @AppStorage("trackingBorderColorString", store: TDNUserDefaults.standard)
    var trackingBorderColorString: String = "13,148,136,0.3"
    @State var trackingBorderColor: Color = .clear

    @AppStorage("imageShouldAutoRotate", store: TDNUserDefaults.standard)
    var imageShouldAutoRotate = false

    @AppStorage("imageFillName", store: TDNUserDefaults.standard)
    var imageFillName: String = Self.defaultFillImageName
    static let defaultFillImageName = "default.png"

    @AppStorage("alpha", store: TDNUserDefaults.standard)
    var alpha: Double = 0.85
    let minimumAlpha: Double = 0.0
    let maximumAlpha: Double = 1.0
    let alphaStep: Double = 0.01

    @AppStorage("fillSize", store: TDNUserDefaults.standard)
    var fillSize: Double = 26.0
    let minimumFillSize: Double = 20.0
    let maximumFillSize: Double = 60.0
    let fillSizeStep: Double = 0.1

    @AppStorage("borderWidth", store: TDNUserDefaults.standard)
    var borderWidth: Double = 2.0
    let minimumBorderWidth: Double = 0.0
    let maximumBorderWidth: Double = 10.0
    let borderWidthStep: Double = 0.1

    @AppStorage("cornerRadius", store: TDNUserDefaults.standard)
    var cornerRadius: Double = 30.0
    let minimumCornerRadius: Double = 0.0
    let maximumCornerRadius: Double = 30.0
    let cornerRadiusStep: Double = 0.1

    @AppStorage("animationDuration", store: TDNUserDefaults.standard)
    var animationDuration: TimeInterval = 0.3
    let minimumAnimationDuration: TimeInterval = 0.0
    let maximumAnimationDuration: TimeInterval = 3.0
    let animationDurationStep: TimeInterval = 0.1

    @AppStorage("liftScale", store: TDNUserDefaults.standard)
    var liftScale: Double = 1.5
    let minimumLiftScale: Double = 1.0
    let maximumLiftScale: Double = 5.0
    let liftScaleStep: Double = 0.1

    @AppStorage("enableOverride", store: TDNUserDefaults.standard)
    var enableOverride: Bool = false

    @AppStorage("disableOverride", store: TDNUserDefaults.standard)
    var disableOverride: Bool = false

    @State var isPresentingResetPrompt = false
    @State private var lastAppliedPresetName: String?
    @State private var isStorageAvailable = TDNUserDefaults.standard.tdn_canPersistSettings()
    @State var isShowingEnableOverrideHint = false
    @State var isShowingDisableOverrideHint = false

    @AppStorage("selectedEmoji", store: TDNUserDefaults.standard)
    var selectedEmoji: String = ""
    @State var isPresentingEmojiPicker = false

    @State var isPresentingFillImagePicker = false
    @State var hasFillImage = false
    @State var fillImage: UIImage?

    private let scrollViewSubject: CurrentValueSubject<UIScrollView?, Never>
    private let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    private let feedbackGenerator: UINotificationFeedbackGenerator = UINotificationFeedbackGenerator()

    init(scrollViewSubject: CurrentValueSubject<UIScrollView?, Never>) {
        self.scrollViewSubject = scrollViewSubject
    }

    func reload() {
        let fillColorString = TDNUserDefaults.standard.string(forKey: "fillColorString") ?? "13,148,136,0.3"
        fillColor = Color(rgbString: fillColorString)

        let borderColorString = TDNUserDefaults.standard.string(forKey: "borderColorString") ?? "13,148,136"
        borderColor = Color(rgbString: borderColorString)

        let quickPathFillColorString = TDNUserDefaults.standard.string(forKey: "quickPathFillColorString") ?? "13,148,136,0.3"
        quickPathFillColor = Color(rgbString: quickPathFillColorString)

        let trackingFillColorString = TDNUserDefaults.standard.string(forKey: "trackingFillColorString") ?? "13,148,136,0.12"
        trackingFillColor = Color(rgbString: trackingFillColorString)

        let trackingBorderColorString = TDNUserDefaults.standard.string(forKey: "trackingBorderColorString") ?? "13,148,136,0.3"
        trackingBorderColor = Color(rgbString: trackingBorderColorString)

        fillImage = Bundle.tdn_fillImageNamed(imageFillName)
        hasFillImage = fillImage != nil && imageFillName != Self.defaultFillImageName
    }

    func reloadOverrides() {
        isStorageAvailable = TDNUserDefaults.standard.tdn_canPersistSettings()
        isShowingEnableOverrideHint = isEnabled && isRecordingOnly && enableOverride
        isShowingDisableOverrideHint = isEnabled && !isRecordingOnly && disableOverride
    }

    var body: some View {
        mainBody
    }

    var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Touch-Dan", bundle: Bundle.tdn_support, comment: ""))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(TDN_COLOR)

                Text(String(format: NSLocalizedString("v%@ · suckdrygod", bundle: Bundle.tdn_support, comment: ""), Bundle.tdn_packageVersion))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("Make every touch easy to follow.", bundle: Bundle.tdn_support, comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .listRowBackground(Color.clear)
    }

    var presetsSection: some View {
        Section {
            ForEach(TDNStylePreset.allCases) { preset in
                Button {
                    preset.apply(to: TDNUserDefaults.standard)
                    reload()
                    reloadOverrides()
                    lastAppliedPresetName = NSLocalizedString(preset.title, bundle: Bundle.tdn_support, comment: "")
                    feedbackGenerator.notificationOccurred(.success)
                } label: {
                    HStack(spacing: 12) {
                        LabelWithSubtitle(
                            NSLocalizedString(preset.title, bundle: Bundle.tdn_support, comment: ""),
                            subtitle: NSLocalizedString(preset.subtitle, bundle: Bundle.tdn_support, comment: ""),
                            systemImage: preset.symbol
                        )
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.down.circle")
                            .imageScale(.medium)
                            .accessibilityHidden(true)
                    }
                    .foregroundColor(TDN_COLOR)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(NSLocalizedString("Apply this style.", bundle: Bundle.tdn_support, comment: ""))
            }
        } header: {
            Text(NSLocalizedString("Style Presets", bundle: Bundle.tdn_support, comment: ""))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let lastAppliedPresetName {
                    Text(String(format: NSLocalizedString("Last applied: %@", bundle: Bundle.tdn_support, comment: ""), lastAppliedPresetName))
                        .foregroundColor(TDN_COLOR)
                }
                Text(NSLocalizedString("Apply a style, then fine-tune below. Your enable switch and saved images are kept.", bundle: Bundle.tdn_support, comment: ""))
            }
        }
    }

    var generalSection: some View {
        Section {
            Toggle(isOn: $isEnabled) {
                LabelWithImageIcon(NSLocalizedString("Enable Touch-Dan", bundle: Bundle.tdn_support, comment: ""), systemImage: "power")
                    .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))

            Toggle(isOn: $isRecordingOnly) {
                LabelWithSubtitle(
                    NSLocalizedString("Only for Recording", bundle: Bundle.tdn_support, comment: ""),
                    subtitle: NSLocalizedString("Displays touch indicators only during screen recording.", bundle: Bundle.tdn_support, comment: ""),
                    systemImage: "dot.circle.and.hand.point.up.left.fill"
                )
                .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))
        } header: {
            Text(NSLocalizedString("General", bundle: Bundle.tdn_support, comment: ""))
        } footer: {
            if !isStorageAvailable {
                Text(NSLocalizedString("Storage is unavailable. Saving has been stopped.", bundle: Bundle.tdn_support, comment: ""))
                    .foregroundColor(.red)
            } else if isShowingEnableOverrideHint {
                Text(NSLocalizedString("Touch-Dan has been turned on from Control Center.", bundle: Bundle.tdn_support, comment: ""))
            } else if isShowingDisableOverrideHint {
                Text(NSLocalizedString("Touch-Dan has been turned off from Control Center.", bundle: Bundle.tdn_support, comment: ""))
            }
        }
    }

    var colorsSection: some View {
        Section {
            ColorPicker(selection: $fillColor) {
                LabelWithImageIcon(NSLocalizedString("Fill Color", bundle: Bundle.tdn_support, comment: ""), systemImage: "paintpalette")
                    .foregroundColor(TDN_COLOR)
            }
            .onChange(of: fillColor) { color in
                fillColorString = color.toRGBString()
            }

            ColorPicker(selection: $borderColor) {
                LabelWithImageIcon(NSLocalizedString("Border Color", bundle: Bundle.tdn_support, comment: ""), systemImage: "paintbrush.pointed")
                    .foregroundColor(TDN_COLOR)
            }
            .onChange(of: borderColor) { color in
                borderColorString = color.toRGBString()
            }
        } header: {
            Text(NSLocalizedString("Touch Colors", bundle: Bundle.tdn_support, comment: ""))
        }
    }

    var alphaSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    alpha = max(minimumAlpha, alpha - alphaStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
                Slider(value: $alpha, in: minimumAlpha...maximumAlpha, step: alphaStep)
                Button {
                    alpha = min(maximumAlpha, alpha + alphaStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            HStack(alignment: .lastTextBaseline) {
                Text(NSLocalizedString("Opacity", bundle: Bundle.tdn_support, comment: ""))
                Spacer()
                Text(String(format: "%.0f%%", alpha * 100))
                    .font(.footnote.monospacedDigit())
                    .textCase(nil)
            }
        }
    }

    var fillSizeSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    fillSize = max(minimumFillSize, fillSize - fillSizeStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
                Slider(value: $fillSize, in: minimumFillSize...maximumFillSize, step: fillSizeStep)
                Button {
                    fillSize = min(maximumFillSize, fillSize + fillSizeStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            HStack(alignment: .lastTextBaseline) {
                Text(NSLocalizedString("Fill Size", bundle: Bundle.tdn_support, comment: ""))
                Spacer()
                Text(String(format: "%.1f pt", fillSize))
                    .font(.footnote.monospacedDigit())
                    .textCase(nil)
            }
        }
    }

    var borderWidthSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    borderWidth = max(minimumBorderWidth, borderWidth - borderWidthStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
                Slider(value: $borderWidth, in: minimumBorderWidth...maximumBorderWidth, step: borderWidthStep)
                Button {
                    borderWidth = min(maximumBorderWidth, borderWidth + borderWidthStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            HStack(alignment: .lastTextBaseline) {
                Text(NSLocalizedString("Border Width", bundle: Bundle.tdn_support, comment: ""))
                Spacer()
                Text(String(format: "%.1f pt", borderWidth))
                    .font(.footnote.monospacedDigit())
                    .textCase(nil)
            }
        }
    }

    var cornerRadiusSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    cornerRadius = max(minimumCornerRadius, cornerRadius - cornerRadiusStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
                Slider(value: $cornerRadius, in: minimumCornerRadius...maximumCornerRadius, step: cornerRadiusStep)
                Button {
                    cornerRadius = min(maximumCornerRadius, cornerRadius + cornerRadiusStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            HStack(alignment: .lastTextBaseline) {
                Text(NSLocalizedString("Corner Radius", bundle: Bundle.tdn_support, comment: ""))
                Spacer()
                Text(String(format: "%.1f pt", cornerRadius))
                    .font(.footnote.monospacedDigit())
                    .textCase(nil)
            }
        }
    }

    var animationDurationSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    animationDuration = max(minimumAnimationDuration, animationDuration - animationDurationStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
                Slider(value: $animationDuration, in: minimumAnimationDuration...maximumAnimationDuration, step: animationDurationStep)
                Button {
                    animationDuration = min(maximumAnimationDuration, animationDuration + animationDurationStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            HStack(alignment: .lastTextBaseline) {
                Text(NSLocalizedString("Animation Duration", bundle: Bundle.tdn_support, comment: ""))
                Spacer()
                Text(String(format: "%.1f s", animationDuration))
                    .font(.footnote.monospacedDigit())
                    .textCase(nil)
            }
        }
    }

    var liftScaleSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    liftScale = max(minimumLiftScale, liftScale - liftScaleStep)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
                Slider(value: $liftScale, in: minimumLiftScale...maximumLiftScale, step: liftScaleStep)
                Button {
                    liftScale = min(maximumLiftScale, liftScale + liftScaleStep)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(TDN_COLOR)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } header: {
            HStack(alignment: .lastTextBaseline) {
                Text(NSLocalizedString("Lift Scale", bundle: Bundle.tdn_support, comment: ""))
                Spacer()
                Text(String(format: "%.1f x", liftScale))
                    .font(.footnote.monospacedDigit())
                    .textCase(nil)
            }
        }
    }

    var effectsSection: some View {
        Section {
            Toggle(isOn: $useTrackingEffect) {
                LabelWithImageIcon(NSLocalizedString("Tracking Effect", bundle: Bundle.tdn_support, comment: ""), systemImage: "circle.hexagonpath")
                    .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))

            Toggle(isOn: $useQuickPathEffect) {
                LabelWithImageIcon(NSLocalizedString("Quick Path Effect", bundle: Bundle.tdn_support, comment: ""), systemImage: "scribble.variable")
                    .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))

            Toggle(isOn: $useMorphEffect) {
                LabelWithImageIcon(NSLocalizedString("Morph Effect", bundle: Bundle.tdn_support, comment: ""), systemImage: "lasso")
                    .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))

            Toggle(isOn: $useImageEffect) {
                LabelWithImageIcon(NSLocalizedString("Image Effect", bundle: Bundle.tdn_support, comment: ""), systemImage: "photo.on.rectangle.angled")
                    .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))
        } header: {
            Text(NSLocalizedString("Effects", bundle: Bundle.tdn_support, comment: ""))
        }
    }

    var quickPathEffectSection: some View {
        Section {
            ColorPicker(selection: $quickPathFillColor) {
                LabelWithImageIcon(NSLocalizedString("Fill Color", bundle: Bundle.tdn_support, comment: ""), systemImage: "paintpalette")
                    .foregroundColor(TDN_COLOR)
            }
            .onChange(of: quickPathFillColor) { color in
                quickPathFillColorString = color.toRGBString()
            }

            Button {
                if useImageEffect, let fillImage, let primaryColor = fillImage.averageColor {
                    quickPathFillColor = Color(uiColor: primaryColor)
                } else {
                    quickPathFillColor = fillColor
                }
                feedbackGenerator.notificationOccurred(.success)
            } label: {
                Label(NSLocalizedString("Use Suggested Colors", bundle: Bundle.tdn_support, comment: ""), systemImage: "doc.on.doc")
                    .foregroundColor(TDN_COLOR)
            }
        } header: {
            Text(NSLocalizedString("Quick Path Effect", bundle: Bundle.tdn_support, comment: ""))
        }
    }

    var trackingEffectSection: some View {
        Section {
            ColorPicker(selection: $trackingFillColor) {
                LabelWithImageIcon(NSLocalizedString("Fill Color", bundle: Bundle.tdn_support, comment: ""), systemImage: "paintpalette")
                    .foregroundColor(TDN_COLOR)
            }
            .onChange(of: trackingFillColor) { color in
                trackingFillColorString = color.toRGBString()
            }

            ColorPicker(selection: $trackingBorderColor) {
                LabelWithImageIcon(NSLocalizedString("Border Color", bundle: Bundle.tdn_support, comment: ""), systemImage: "paintbrush.pointed")
                    .foregroundColor(TDN_COLOR)
            }
            .onChange(of: trackingBorderColor) { color in
                trackingBorderColorString = color.toRGBString()
            }

            Button {
                trackingFillColor = fillColor.opacity(0.4)
                trackingBorderColor = borderColor.opacity(0.4)
                feedbackGenerator.notificationOccurred(.success)
            } label: {
                Label(NSLocalizedString("Use Suggested Colors", bundle: Bundle.tdn_support, comment: ""), systemImage: "doc.on.doc")
                    .foregroundColor(TDN_COLOR)
            }
        } header: {
            Text(NSLocalizedString("Tracking Effect", bundle: Bundle.tdn_support, comment: ""))
        }
    }

    var imageEffectOptionSection: some View {
        Section {
            Toggle(isOn: $imageShouldAutoRotate) {
                LabelWithSubtitle(
                    NSLocalizedString("Auto Rotate", bundle: Bundle.tdn_support, comment: ""),
                    subtitle: NSLocalizedString("Automatically rotates the image to match the path direction.", bundle: Bundle.tdn_support, comment: ""),
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .foregroundColor(TDN_COLOR)
            }
            .toggleStyle(SwitchToggleStyle(tint: TDN_COLOR))

            Button {
                fillColor = .clear
                borderColor = .clear
                trackingFillColor = .clear
                trackingBorderColor = .clear
                feedbackGenerator.notificationOccurred(.success)
            } label: {
                Label(NSLocalizedString("Use Clear Colors", bundle: Bundle.tdn_support, comment: ""), systemImage: "circle.dashed")
                    .foregroundColor(TDN_COLOR)
            }
        } header: {
            Text(NSLocalizedString("Image Effect", bundle: Bundle.tdn_support, comment: ""))
        }
    }

    var imageEffectPreview: some View {
        VStack(alignment: .center) {
            if let fillImage {
                Image(uiImage: fillImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeIn, value: fillImage)
    }

    var imageEffectSection: some View {
        Section {
            Group {
                if #available(iOS 16.0, *) {
                    imageEffectPreview
                } else {
                    imageEffectPreview
                        .padding(.vertical, 8)
                }
            }
            .emojiPicker(
                isPresented: $isPresentingEmojiPicker,
                selectedEmoji: $selectedEmoji,
                arrowDirection: .down
            )

            Button {
                isPresentingEmojiPicker.toggle()
            } label: {
                Label(NSLocalizedString("Select Emoji", bundle: Bundle.tdn_support, comment: ""), systemImage: "face.smiling")
                    .foregroundColor(TDN_COLOR)
            }

            Button {
                isPresentingFillImagePicker.toggle()
            } label: {
                Label(NSLocalizedString("Select Image", bundle: Bundle.tdn_support, comment: ""), systemImage: "doc.badge.plus")
                    .foregroundColor(TDN_COLOR)
            }
        } header: {
            Text(NSLocalizedString("Custom Image", bundle: Bundle.tdn_support, comment: ""))
        }
        .onChange(of: selectedEmoji) { emoji in
            guard !emoji.isEmpty else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard TDNUserDefaults.standard.tdn_canPersistSettings() else {
                    feedbackGenerator.notificationOccurred(.error)
                    return
                }
                withAnimation {
                    finishSavingFillImage(Bundle.tdn_saveFillImage(with: emoji.render(size: String.nativeEmojiSize)))
                }
            }
        }
    }

    var resetSection: some View {
        Section {
            Button(role: .destructive) {
                isPresentingResetPrompt = true
            } label: {
                Label(NSLocalizedString("Reset to Default", bundle: Bundle.tdn_support, comment: ""), systemImage: "arrow.counterclockwise")
                    .foregroundColor(TDN_COLOR)
            }
        } footer: {
            Text(String(format: "%@\n\n%@",
                NSLocalizedString("Touch-Dan by suckdrygod. Based on Touch-Viz by OwnGoal Studio.\nOriginal work © 2024–2026 OwnGoal Studio (MIT License).", bundle: Bundle.tdn_support, comment: ""),
                NSLocalizedString("Credits:\nLeoNatan / Joe Blau: LNTouchVisualizer (MIT)\nIvan Izyumkin: MCEmojiPicker (MIT)\nTimber Software: SwiftUI Introspect (MIT)", bundle: Bundle.tdn_support, comment: "")))
                .padding(.bottom, 8)
        }
    }

    var resetPrompt: Alert {
        Alert(
            title: Text(NSLocalizedString("Reset to Default", bundle: Bundle.tdn_support, comment: "")),
            message: Text(NSLocalizedString("Are you sure you want to reset all settings to their default values?", bundle: Bundle.tdn_support, comment: "")),
            primaryButton: .cancel(),
            secondaryButton: .destructive(Text(NSLocalizedString("Reset", bundle: Bundle.tdn_support, comment: ""))) {
                guard TDNUserDefaults.standard.tdn_canPersistSettings(), Bundle.tdn_removeAllFillImages() else {
                    feedbackGenerator.notificationOccurred(.error)
                    return
                }
                withAnimation {
                    TDNUserDefaults.standard.resetToDefaultValues()
                    lastAppliedPresetName = nil
                    reload()
                    reloadOverrides()
                }
            }
        )
    }

    var mainBody: some View {
        Form {
            header
            generalSection
            presetsSection
            colorsSection
            alphaSection
            fillSizeSection
            borderWidthSection
            cornerRadiusSection
            animationDurationSection
            liftScaleSection
            effectsSection

            if useTrackingEffect {
                trackingEffectSection
            }

            if useQuickPathEffect {
                quickPathEffectSection
            }

            if useImageEffect {
                imageEffectOptionSection
                imageEffectSection
            }

            resetSection
        }
        .disabled(!isStorageAvailable)
        .tint(TDN_COLOR)
        .transition(.opacity)
        .listStyle(.insetGrouped)
        .animation(.easeIn, value: useQuickPathEffect)
        .animation(.easeIn, value: useTrackingEffect)
        .animation(.easeIn, value: useImageEffect)
        .animation(.easeIn, value: hasFillImage)
        .alert(isPresented: $isPresentingResetPrompt) { resetPrompt }
        .fileImporter(
            isPresented: $isPresentingFillImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: fileImporterResultHandler
        )
        .onAppear {
            reload()
            reloadOverrides()
        }
        .onReceive(timer) { _ in
            withAnimation {
                reloadOverrides()
            }
        }
        .introspect(.list, on: .iOS(.v13, .v14, .v15)) {
            scrollViewSubject.send($0)
        }
        .introspect(.list, on: .iOS(.v16, .v17, .v18)) {
            scrollViewSubject.send($0)
        }
    }

    private func fileImporterResultHandler(result: Result<[URL], Error>) {
        do {
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }
                guard url.isFileURL, TDNUserDefaults.standard.tdn_canPersistSettings() else {
                    feedbackGenerator.notificationOccurred(.error)
                    return
                }
                let hasScopedAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasScopedAccess { url.stopAccessingSecurityScopedResource() }
                }
                withAnimation {
                    finishSavingFillImage(Bundle.tdn_saveFillImage(withPath: url.path))
                }
            case .failure(let error):
                throw error
            }
        } catch {
            feedbackGenerator.notificationOccurred(.error)
        }
    }

    private func finishSavingFillImage(_ name: String?) {
        guard let name else {
            feedbackGenerator.notificationOccurred(.error)
            return
        }
        imageFillName = name
        let cleaned = Bundle.tdn_removeUnusedFillImages(keeping: name)
        TDNUserDefaults.standard.darwinNotify()
        reload()
        feedbackGenerator.notificationOccurred(cleaned ? .success : .warning)
    }
}
