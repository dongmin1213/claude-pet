import AppKit
import SwiftUI

// MARK: - Layout constants

let MAIN_W: CGFloat = 92    // width of each row's main-crab block
let ROW_H:  CGFloat = 88    // height of one session row (incl. icon + label space)
let TOP_PAD: CGFloat = 20   // headroom above the first row for status icons
let MINI_W: CGFloat = 34    // width of each subagent mini-crab slot
let MAIN_PX: CGFloat = 4
let MINI_PX: CGFloat = 2

// MARK: - Model

enum PetState: String { case idle, working, done, waiting }

struct Session: Equatable {
    let id: String
    let state: PetState
    let agents: Int
    let born: Double
    let label: String
    static func == (a: Session, b: Session) -> Bool {
        a.id == b.id && a.state == b.state && a.agents == b.agents && a.label == b.label
    }
}

/// Reads per-session tokens written by Claude Code hooks under
/// ~/.claude-pet/sessions/<session_id>/{state,agents,born}.
/// Falls back to a single "default" session from legacy ~/.claude-pet/{state,agents}.
final class StateStore: ObservableObject {
    @Published var sessions: [Session] = [Session(id: "default", state: .idle, agents: 0, born: 0, label: "")]
    var onResize: ((CGSize) -> Void)?

    private let base: String
    private let legacyState: String
    private let legacyAgents: String
    private var doneSince: [String: Date] = [:]
    private var timer: Timer?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        base = home + "/.claude-pet/sessions"
        legacyState = home + "/.claude-pet/state"
        legacyAgents = home + "/.claude-pet/agents"
        poll()
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func contentSize(for list: [Session]) -> CGSize {
        let maxA = list.map { $0.agents }.max() ?? 0
        let rows = max(1, list.count)
        return CGSize(width: MAIN_W + CGFloat(maxA) * MINI_W, height: CGFloat(rows) * ROW_H + TOP_PAD)
    }

    private func token(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func resolved(id: String, raw: String, agents: Int, born: Double, label: String) -> Session {
        var st = PetState(rawValue: raw) ?? .idle
        let now = Date()
        if st == .done {
            if doneSince[id] == nil { doneSince[id] = now }
            if now.timeIntervalSince(doneSince[id]!) > 4 { st = .idle }
        } else {
            doneSince[id] = nil
        }
        return Session(id: id, state: st, agents: max(0, agents), born: born, label: label)
    }

    private func poll() {
        let fm = FileManager.default
        var list: [Session] = []
        if let entries = try? fm.contentsOfDirectory(atPath: base) {
            for id in entries {
                let dir = base + "/" + id
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { continue }
                let st = token(dir + "/state")
                let ag = Int(token(dir + "/agents")) ?? 0
                let born = Double(token(dir + "/born")) ?? 0
                let lb = token(dir + "/label")
                list.append(resolved(id: id, raw: st.isEmpty ? "idle" : st, agents: ag, born: born, label: lb))
            }
        }
        if list.isEmpty {
            let st = token(legacyState)
            let ag = Int(token(legacyAgents)) ?? 0
            list = [resolved(id: "default", raw: st.isEmpty ? "idle" : st, agents: ag, born: 0, label: "")]
        }
        list.sort { $0.born != $1.born ? $0.born < $1.born : $0.id < $1.id }

        if list != sessions {
            let oldSize = contentSize(for: sessions)
            let newSize = contentSize(for: list)
            DispatchQueue.main.async {
                self.sessions = list
                if oldSize != newSize { self.onResize?(newSize) }
            }
        }
    }
}

// MARK: - Palette

struct Palette { let body, dark, light, eye, cream: Color }

// MARK: - Renderer

enum Renderer {
    static let eye   = Color(red: 0.165, green: 0.102, blue: 0.071)
    static let cream = Color(red: 0.969, green: 0.937, blue: 0.886)

    static let main = Palette(
        body:  Color(red: 0.851, green: 0.467, blue: 0.341),
        dark:  Color(red: 0.722, green: 0.353, blue: 0.235),
        light: Color(red: 0.910, green: 0.608, blue: 0.494),
        eye: eye, cream: cream)

    static let minis: [Palette] = [
        Palette(body: .init(red: 0.31, green: 0.70, blue: 0.65), dark: .init(red: 0.18, green: 0.51, blue: 0.47), light: .init(red: 0.50, green: 0.83, blue: 0.78), eye: eye, cream: cream),
        Palette(body: .init(red: 0.61, green: 0.48, blue: 0.85), dark: .init(red: 0.43, green: 0.32, blue: 0.66), light: .init(red: 0.74, green: 0.64, blue: 0.91), eye: eye, cream: cream),
        Palette(body: .init(red: 0.44, green: 0.75, blue: 0.35), dark: .init(red: 0.30, green: 0.56, blue: 0.22), light: .init(red: 0.58, green: 0.85, blue: 0.51), eye: eye, cream: cream),
        Palette(body: .init(red: 0.88, green: 0.48, blue: 0.66), dark: .init(red: 0.69, green: 0.32, blue: 0.49), light: .init(red: 0.94, green: 0.64, blue: 0.78), eye: eye, cream: cream),
        Palette(body: .init(red: 0.35, green: 0.61, blue: 0.88), dark: .init(red: 0.22, green: 0.44, blue: 0.69), light: .init(red: 0.51, green: 0.74, blue: 0.94), eye: eye, cream: cream),
        Palette(body: .init(red: 0.88, green: 0.70, blue: 0.31), dark: .init(red: 0.69, green: 0.52, blue: 0.18), light: .init(red: 0.94, green: 0.81, blue: 0.50), eye: eye, cream: cream),
    ]

    static let sprite: [String] = [
        "................",
        "...D........D...",
        "..LOL......LOL..",
        "...DOOOOOOOOD...",
        "..OOOOOOOOOOOO..",
        "..OOEEOOOOEEOO..",
        "..OOEEOOOOEEOO..",
        "..OOOOOOOOOOOO..",
        "..LOOOOOOOOOOL..",
        "...OOOOOOOOOO...",
        "...D.D.DD.D.D...",
        "................",
    ]

    static func color(_ ch: Character, _ pal: Palette) -> Color {
        switch ch {
        case "O": return pal.body
        case "D": return pal.dark
        case "L": return pal.light
        case "E": return pal.eye
        case "W": return pal.cream
        default:  return pal.body
        }
    }

    static func rectPath(_ r: CGRect) -> Path { var p = Path(); p.addRect(r); return p }

    static func spark(_ ctx: GraphicsContext, _ c: CGPoint, _ s: CGFloat, _ color: Color) {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addLine(to: CGPoint(x: c.x + s*0.3, y: c.y - s*0.3))
        p.addLine(to: CGPoint(x: c.x + s, y: c.y))
        p.addLine(to: CGPoint(x: c.x + s*0.3, y: c.y + s*0.3))
        p.addLine(to: CGPoint(x: c.x, y: c.y + s))
        p.addLine(to: CGPoint(x: c.x - s*0.3, y: c.y + s*0.3))
        p.addLine(to: CGPoint(x: c.x - s, y: c.y))
        p.addLine(to: CGPoint(x: c.x - s*0.3, y: c.y - s*0.3))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    @discardableResult
    static func drawSprite(_ ctx: GraphicsContext, centerX: CGFloat, groundY: CGFloat,
                           px: CGFloat, pal: Palette, bob: CGFloat,
                           eyeShift: CGFloat, blink: Bool) -> CGFloat {
        let cols = 16, rows = 12
        let sw = px * CGFloat(cols), sh = px * CGFloat(rows)
        let originX = (centerX - sw/2).rounded()
        let topY = (groundY - sh - bob).rounded()

        let shW = sw * (0.7 - bob/300)
        ctx.fill(Path(ellipseIn: CGRect(x: centerX - shW/2, y: groundY - px*0.6, width: shW, height: px*1.2)),
                 with: .color(.black.opacity(0.16)))

        for r in 0..<rows {
            let chars = Array(sprite[r])
            for c in 0..<cols {
                let ch = chars[c]
                if ch == "." { continue }
                var x = originX + CGFloat(c) * px
                var y = topY + CGFloat(r) * px
                let w = px
                var h = px
                if ch == "E" {
                    x += eyeShift
                    if blink { y += px * 0.6; h = px * 0.4 }
                }
                ctx.fill(rectPath(CGRect(x: x, y: y, width: w, height: h)), with: .color(color(ch, pal)))
            }
        }
        return topY
    }

    static let cDone = Color(red: 0.30, green: 0.69, blue: 0.31) // green (done sparkle)

    /// Draws one session's main crab on its row. State is shown by an emoji
    /// status icon plus a distinct motion (no background).
    static func drawMain(_ ctx: GraphicsContext, state: PetState, label: String, centerX: CGFloat, groundY: CGFloat, time: Double) {
        let px = MAIN_PX
        let sw = px * 16, sh = px * 12
        let blink = time.truncatingRemainder(dividingBy: 3.4) > 3.24

        var bob: CGFloat = 0, eyeShift: CGFloat = 0
        var icon = "", iconBounce: CGFloat = 0

        switch state {
        case .working:
            bob = CGFloat(sin(time * 7.0)) * 2.5 + 3; icon = "🔨"
        case .idle:
            let hop = time.truncatingRemainder(dividingBy: 5.0)
            if hop < 0.4 { bob = CGFloat(sin(hop / 0.4 * .pi)) * 7 }
            else { bob = CGFloat(sin(time * 1.6)) * 1.0 }
            icon = "💤"
        case .done:
            bob = abs(CGFloat(sin(time * 6.0))) * 7 + 2; icon = "✅"
        case .waiting:
            eyeShift = CGFloat(sin(time * 2.0)) * 1.2
            bob = CGFloat(sin(time * 2.0)) * 1.0
            icon = "💬"; iconBounce = CGFloat(abs(sin(time * 4.0))) * 3
        }

        let topY = (groundY - sh - bob).rounded()

        drawSprite(ctx, centerX: centerX, groundY: groundY, px: px, pal: main, bob: bob, eyeShift: eyeShift, blink: blink)

        // celebratory sparkle burst when done
        if state == .done {
            for i in 0..<3 {
                let a = time * 2.5 + Double(i) * (2 * Double.pi / 3)
                let sx = centerX + CGFloat(cos(a)) * sw * 0.62
                let sy = (topY + sh/2) + CGFloat(sin(a)) * sh * 0.42
                let tw = 0.4 + 0.6 * abs(CGFloat(sin(time * 5 + Double(i))))
                spark(ctx, CGPoint(x: sx, y: sy), 4, cDone.opacity(Double(tw)))
            }
        }

        // emoji status icon above the head — fixed height (independent of bob)
        // so a jumping crab never collides with the row above's label
        if !icon.isEmpty {
            let iconY = (groundY - sh) - 9 - iconBounce
            ctx.draw(Text(icon).font(.system(size: 12)),
                     at: CGPoint(x: centerX, y: iconY))
        }

        // session label (folder name) under the crab
        if !label.isEmpty {
            let shown = label.count > 14 ? String(label.prefix(13)) + "…" : label
            let pillW = CGFloat(shown.count) * 5.4 + 10
            let cyLabel = groundY + 9
            let pill = CGRect(x: centerX - pillW/2, y: cyLabel - 6.5, width: pillW, height: 13)
            ctx.fill(Path(roundedRect: pill, cornerRadius: 6), with: .color(.black.opacity(0.45)))
            ctx.draw(Text(shown).font(.system(size: 9, weight: .medium)).foregroundColor(.white),
                     at: CGPoint(x: centerX, y: cyLabel))
        }
    }

    static func draw(ctx: GraphicsContext, size: CGSize, sessions: [Session], time: Double) {
        for (row, s) in sessions.enumerated() {
            let groundY = TOP_PAD + CGFloat(row) * ROW_H + (ROW_H - 16)
            drawMain(ctx, state: s.state, label: s.label, centerX: MAIN_W / 2, groundY: groundY, time: time)
            if s.agents > 0 {
                for j in 0..<s.agents {
                    let pal = minis[j % minis.count]
                    let slotCenter = MAIN_W + CGFloat(j) * MINI_W + MINI_W / 2
                    let phase = Double(j) * 0.7 + Double(row)
                    let mbob = abs(CGFloat(sin(time * 5 + phase))) * 5 + 1
                    let mblink = (time + Double(j) + Double(row)).truncatingRemainder(dividingBy: 3.0) > 2.85
                    drawSprite(ctx, centerX: slotCenter, groundY: groundY, px: MINI_PX, pal: pal,
                               bob: mbob, eyeShift: 0, blink: mblink)
                }
            }
        }
    }
}

// MARK: - SwiftUI view

struct PetRootView: View {
    @ObservedObject var store: StateStore
    var size: CGSize { store.contentSize(for: store.sessions) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { tl in
            Canvas { ctx, sz in
                Renderer.draw(ctx: ctx, size: sz, sessions: store.sessions,
                              time: tl.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Panel content (crab scene + bubble background)

let PANEL_PAD: CGFloat = 10

struct PanelView: View {
    @ObservedObject var store: StateStore
    var body: some View {
        PetRootView(store: store)
            .padding(PANEL_PAD)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.11).opacity(0.94))
            )
    }
}

// MARK: - Menu bar item + manually-positioned panel

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = StateStore()
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var hosting: NSHostingView<PanelView>!
    var titleTimer: Timer?
    var clickMonitor: Any?

    /// One glanceable summary for the menu bar. Priority: working > waiting >
    /// done > idle. Shows a count when more than one session shares the state.
    func menuTitle() -> String {
        let s = store.sessions.filter { $0.id != "default" || !($0.state == .idle && $0.agents == 0) }
        let working = s.filter { $0.state == .working }.count
        let waiting = s.filter { $0.state == .waiting }.count
        let done    = s.filter { $0.state == .done }.count
        func tag(_ icon: String, _ n: Int) -> String { n > 1 ? "\(icon)\(n)" : icon }
        if working > 0 { return "🦀" + tag("🔨", working) }
        if waiting > 0 { return "🦀" + tag("💬", waiting) }
        if done    > 0 { return "🦀" + tag("✅", done) }
        return "🦀"
    }

    func panelSize() -> CGSize {
        let c = store.contentSize(for: store.sessions)
        return CGSize(width: c.width + PANEL_PAD * 2, height: c.height + PANEL_PAD * 2)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Borderless floating panel hosts the animated crab scene.
        hosting = NSHostingView(rootView: PanelView(store: store))
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: panelSize()),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting

        // Menu bar item.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = menuTitle()
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Keep the menu bar title in sync with state.
        titleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.statusItem.button?.title = self?.menuTitle() ?? "🦀"
        }

        // Re-fit/re-anchor the panel as sessions change while it's open.
        store.onResize = { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }
            self.positionPanel()
        }
        store.start()
    }

    @objc func statusClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    func togglePanel() {
        if panel.isVisible { closePanel() } else { openPanel() }
    }

    /// Place the panel directly under the status item button, clamped on screen.
    func positionPanel() {
        guard let button = statusItem.button, let bw = button.window else { return }
        let size = panelSize()
        hosting.frame = NSRect(origin: .zero, size: size)
        let bf = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = bw.screen ?? NSScreen.main
        let vf = screen?.visibleFrame ?? bf
        var x = bf.midX - size.width / 2
        x = min(max(x, vf.minX + 4), vf.maxX - size.width - 4)
        let y = bf.minY - size.height               // hang below the menu bar
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    func openPanel() {
        positionPanel()
        panel.orderFrontRegardless()
        // dismiss when the user clicks anywhere outside the panel
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    func closePanel() {
        panel.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    func showMenu() {
        closePanel()
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Claude Pet 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil                    // detach so left-click keeps toggling the panel
    }
}

// single instance: bail out if another copy is already running
if let bid = Bundle.main.bundleIdentifier {
    let myPid = ProcessInfo.processInfo.processIdentifier
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
        .filter { $0.processIdentifier != myPid }
    if !others.isEmpty { exit(0) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
