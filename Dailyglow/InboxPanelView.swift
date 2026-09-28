import AppKit
import SwiftUI

struct InboxPanelView: View {
  var isCompact = false
  @State private var showCompactInbox = false
  @State private var compactCategory: String?
  @State private var collapsedCategories: Set<String> = ["Work", "Life"]
  @State private var categoryDrafts: [String: String] = [:]
  private let projectURL = "https://jhpacvtyylpcmgvfvzex.supabase.co"
  @State private var hasCredential = false
  @State private var notes: [InboxNote] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showConnection = false
  @State private var draftSecret = ""
  @State private var connectionError: String?
  @State private var editingNote: InboxNote?
  @State private var editBody = ""
  @State private var editError: String?
  @State private var pendingDeletion: InboxNote?
  @State private var confirmDeletion = false
  @State private var isMutating = false

  @State private var local = InboxLocalState.load()
  @State private var newTask = ""
  @State private var isInboxCollapsed = true
  @State private var isInboxHeaderHovered = false
  @State private var isTodayCollapsed = false
  @State private var isTodayNotesExpanded = false
  @State private var todayDetached = false
  @State private var detachDragEvent: NSEvent?
  @State private var todayPinned = true
  @State private var todayTask = ""
  @FocusState private var addingTodayTask: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dropTarget: UUID?
  @FocusState private var addingTask: Bool
  @Environment(\.colorScheme) private var colorScheme

  private var allTasks: [InboxNote] {
    let drafts = local.drafts.map {
      InboxNote(id: $0.id, body: $0.body, source: "local", captured_at: "")
    }
    let ranks = Dictionary(
      local.order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
    return (notes + drafts).sorted {
      let leftDone = local.completed.contains($0.id)
      let rightDone = local.completed.contains($1.id)
      if leftDone != rightDone { return !leftDone }
      return (ranks[$0.id] ?? Int.max) < (ranks[$1.id] ?? Int.max)
    }
  }

  var body: some View {
    panelContent
      .frame(width: isCompact ? 280 : nil)
      .opacity(isCompact ? 0 : 1)
      .allowsHitTesting(!isCompact)
      .accessibilityHidden(isCompact)
      .frame(width: isCompact ? 40 : nil)
      .clipped()
      .overlay(alignment: .topLeading) {
        if isCompact { compactSections }
      }
      .padding(.horizontal, 8)
      .padding(.top, 2)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .task { await refresh() }
      .onChange(of: todayDetached) { _, detached in
        if detached {
          isTodayCollapsed = false
          isTodayNotesExpanded = true
        }
      }
      .onChange(of: local) { _, state in
        if let data = try? JSONEncoder().encode(state) {
          UserDefaults.standard.set(data, forKey: InboxLocalState.key)
        }
      }
      .alert("Permanently delete this note?", isPresented: $confirmDeletion) {
        Button("Delete", role: .destructive) {
          if let note = pendingDeletion {
            Task { await changeNote(note, body: nil) }
          }
          pendingDeletion = nil
        }
        Button("Cancel", role: .cancel) { pendingDeletion = nil }
      } message: {
        Text(
          pendingDeletion.map { isLocal($0.id) } == true
            ? "This removes the task from this Mac."
            : "This removes the note from Supabase and cannot be undone.")
      }
      .sheet(item: $editingNote) { note in
        editSheet(note)
      }
      .sheet(isPresented: $showConnection) {
        connectionSheet
      }
  }

  private func editSheet(_ note: InboxNote) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Edit note").font(.headline)
      TextEditor(text: $editBody).frame(minHeight: 180).disabled(isMutating)
      if let editError { Text(editError).foregroundStyle(.red).font(.caption) }
      HStack {
        if isMutating { ProgressView().controlSize(.small) }
        Spacer()
        Button("Cancel") { editingNote = nil }.disabled(isMutating)
        Button("Save") { Task { await changeNote(note, body: editBody) } }
          .disabled(
            isMutating || editBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 440).interactiveDismissDisabled(isMutating)
  }

  private var connectionSheet: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Connect Supabase inbox").font(.headline)
      SecureField("Inbox secret", text: $draftSecret)
      Text(
        "Use READ_NOTES_SECRET from your read-notes function. Stored in Keychain. Leave blank to keep a saved secret for this project."
      )
      .font(.caption).foregroundStyle(.secondary)
      if let connectionError { Text(connectionError).foregroundStyle(.red).font(.caption) }
      HStack {
        Spacer()
        Button("Cancel") {
          draftSecret = ""
          showConnection = false
        }
        Button("Connect") { connect() }.keyboardShortcut(.defaultAction)
      }
    }.padding(24).frame(width: 420)
  }

  private var compactSections: some View {
    VStack(spacing: 12) {
      Button {
        isTodayCollapsed = false
        detachDragEvent = nil
        todayDetached.toggle()
      } label: {
        Image(systemName: "sun.max")
          .frame(width: 40, height: 40)
          .background(sectionColor(today: true), in: RoundedRectangle(cornerRadius: 13))
      }
      .help("Show Today")
      .accessibilityLabel("Show Today")
      Divider()
        .opacity(0.5)
        .frame(width: 24)
      Button {
        isInboxCollapsed = false
        showCompactInbox.toggle()
      } label: {
        Image(systemName: "tray")
          .frame(width: 40, height: 40)
          .background(sectionColor(today: false), in: RoundedRectangle(cornerRadius: 13))
      }
      .help("Show Inbox")
      .accessibilityLabel("Show Inbox")
      .popover(isPresented: $showCompactInbox, arrowEdge: .trailing) {
        ScrollView { taskSection(today: false).padding(12) }
          .frame(width: 320, height: 480)
      }
      ForEach(["Work", "Life"], id: \.self) { category in
        Button { compactCategory = category } label: {
          Image(systemName: category == "Work" ? "briefcase" : "heart")
            .frame(width: 40, height: 40)
            .background((category == "Work" ? Color.blue : Color.purple).opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
        }
        .help("Show " + category)
        .accessibilityLabel("Show " + category)
        .popover(isPresented: Binding(get: { compactCategory == category }, set: { if !$0 { compactCategory = nil } })) {
          ScrollView { categorySection(category).padding(12) }.frame(width: 320, height: 480)
        }
      }
    }
    .buttonStyle(.plain)
    .onChange(of: isCompact) { _, compact in
      if !compact { showCompactInbox = false }
    }
  }

  private var panelContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      if let errorMessage {
        Text(errorMessage).font(.caption).foregroundStyle(.red)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          TodayWindowPortal(
            detached: $todayDetached, pinned: todayPinned, collapsed: isTodayCollapsed, dragEvent: detachDragEvent,
            content: AnyView(taskSection(today: true)))
          if !todayDetached {
            Divider()
              .opacity(0.5)
              .padding(.horizontal, 8)
          }
          taskSection(today: false)
          categorySection("Work")
          categorySection("Life")
          if !isLoading && (!hasCredential || errorMessage != nil) {
            Button("Connect inbox…") {
              draftSecret = ""
              connectionError = nil
              showConnection = true
            }
            .buttonStyle(.plain)
            .font(.caption)
          }
          Text("Everything starts here.").font(.caption).foregroundStyle(.secondary).padding(
            .horizontal, 5)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private func setCategory(_ id: UUID, category: String?) {
    local.todayIDs?.remove(id)
    var categories = local.categories ?? [:]
    categories[id.uuidString] = category
    local.categories = categories
  }

  private func acceptCategorizedDrop(_ items: [String], before target: UUID?, category: String?, today: Bool = false) -> Bool {
    guard acceptDrop(items, before: target, today: today) else { return false }
    if let category, let value = items.first,
       let id = UUID(uuidString: String(value.dropFirst("dailyglow-inbox:".count))) {
      setCategory(id, category: category)
    }
    return true
  }

  private func categorySection(_ category: String) -> some View {
    let tasks = allTasks.filter { local.categories?[$0.id.uuidString] == category }
    let collapsed = collapsedCategories.contains(category)
    let accent: Color = category == "Work" ? .blue : .purple
    return TaskSectionView(collapsed: collapsed, accent: accent, background: accent.opacity(0.1)) {
      Button {
        if !collapsedCategories.insert(category).inserted { collapsedCategories.remove(category) }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: category == "Work" ? "briefcase" : "heart")
            .frame(width: 29, height: 29)
            .background(accent.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
          Text(category).font(.system(size: 19, weight: .medium))
            .foregroundStyle(.black)
          Text("\(tasks.filter { !local.completed.contains($0.id) }.count)").font(.system(size: 13)).foregroundStyle(.secondary)
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    } content: {
      if !collapsed {
        LazyVStack(spacing: 7) { ForEach(tasks) { taskRow($0) } }
        TextField("Add a task…", text: Binding(get: { categoryDrafts[category] ?? "" }, set: { categoryDrafts[category] = $0 }))
          .textFieldStyle(.plain).font(.system(size: 14))
          .padding(.horizontal, 5).padding(.vertical, 6)
          .onSubmit {
            let title = (categoryDrafts[category] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            let id = UUID()
            local.order = allTasks.map(\.id) + [id]
            local.drafts.append(.init(id: id, body: title))
            setCategory(id, category: category)
            categoryDrafts[category] = ""
          }
      }
    }
    .contentShape(Rectangle())
    .dropDestination(for: String.self) { items, _ in
      return acceptCategorizedDrop(items, before: nil, category: category)
    }
  }

  private func sectionTasks(today: Bool) -> [InboxNote] {
    allTasks.filter { (local.todayIDs?.contains($0.id) ?? false) == today && (today || local.categories?[$0.id.uuidString] == nil) }
  }

  private func taskSection(today: Bool) -> some View {
    let collapsed = today ? isTodayCollapsed : isInboxCollapsed
    let accent: Color = today ? .yellow : .green
    let header = HStack(spacing: 8) {
        Button {
          guard !(today && todayDetached) else { return }
          addingTask = false
          addingTodayTask = false
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            if today { isTodayCollapsed.toggle() } else { isInboxCollapsed.toggle() }
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: today ? "sun.max" : "tray")
              .frame(width: 29, height: 29)
              .background(accent.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
              .overlay {
                if today {
                  TodayWindowDragHandle(detached: todayDetached) { event in
                    detachDragEvent = event
                    todayDetached = true
                  } onClick: {
                    detachDragEvent = nil
                    todayDetached.toggle()
                  }
                  .help(todayDetached ? "Click to dock Today · Drag to move" : "Click or drag to pop out Today")
                }
              }
            Text(today ? "Today" : "Inbox").font(.system(size: 19, weight: .medium))
              .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            Text("\(sectionTasks(today: today).filter { !local.completed.contains($0.id) }.count)")
              .font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
          }.contentShape(Rectangle())
          .overlay {
            if today && todayDetached {
              TodayWindowDragHandle(detached: true, onDetach: { _ in }, onClick: {})
                .padding(.leading, 37)
            }
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(today ? "Today" : "Inbox")
        .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
        .accessibilityHint("Activate to toggle task visibility")
        .contextMenu {
          if today && todayDetached {
            Button(collapsed ? "Expand Today" : "Collapse Today") { isTodayCollapsed.toggle() }
            Button("Return to main window") { todayDetached = false }
          }
        }
        if today {
          if todayDetached {
            Button {
              todayPinned.toggle()
            } label: {
              Image(systemName: todayPinned ? "pin.fill" : "pin")
                .frame(width: 26, height: 28)
            }
            .buttonStyle(.plain)
            .help(todayPinned ? "Turn off Always on Top" : "Always on Top")
            .accessibilityLabel("Always on Top")
            .accessibilityValue(todayPinned ? "On" : "Off")
          }

        }
        if !today {
          Button {
            Task { await refresh() }
          } label: {
            Image(systemName: "arrow.clockwise").frame(width: 28, height: 28)
          }
          .buttonStyle(.plain)
          .help("Refresh inbox")
          .accessibilityLabel("Refresh inbox")
          .disabled(!hasCredential || isLoading || isMutating)
          .opacity(isInboxHeaderHovered ? 1 : 0)
          .allowsHitTesting(isInboxHeaderHovered)
          if isLoading { ProgressView().controlSize(.small) }
        }

      }
      .contentShape(Rectangle())
      .onHover { hovering in
        if !today { isInboxHeaderHovered = hovering }
      }
      .dropDestination(for: String.self) { items, _ in
        return acceptDrop(items, before: nil, today: today)
      }
    let contents = VStack(alignment: .leading, spacing: collapsed ? 0 : 7) {
      if !collapsed {
        LazyVStack(spacing: 7) {
          ForEach(sectionTasks(today: today)) { note in taskRow(note) }
        }
        if sectionTasks(today: today).isEmpty {
          Text(today ? "Drag a task here to plan your day." : "A little room for what’s next.")
            .font(.system(size: 14)).foregroundStyle(.secondary)
            .padding(.vertical, 16).padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
              return acceptDrop(items, before: nil, today: today)
            }
        }
        taskComposer(today: today)
      }
      if today {
        TodayNotesView(isExpanded: $isTodayNotesExpanded, collapsed: collapsed, detached: todayDetached)
      }
    }

    return TaskSectionView(
      collapsed: collapsed, accent: accent, background: sectionColor(today: today),
      scrollsContent: today && todayDetached
    ) {
      header
    } content: {
      contents
    }
  }

  private func sectionColor(today: Bool) -> Color {
    if colorScheme == .dark {
      return today
        ? Color(red: 0.22, green: 0.20, blue: 0.13) : Color(red: 0.13, green: 0.22, blue: 0.16)
    }
    return today
      ? Color(red: 1, green: 0.965, blue: 0.83) : Color(red: 0.91, green: 0.97, blue: 0.89)
  }

  private func taskComposer(today: Bool) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "plus").foregroundStyle(.secondary)
      if today {
        TextField("Add a task…", text: $todayTask)
          .focused($addingTodayTask)
          .onSubmit { addTask(today: true) }
      } else {
        TextField("Add a task…", text: $newTask)
          .focused($addingTask)
          .onSubmit { addTask(today: false) }
      }
    }
    .textFieldStyle(.plain).font(.system(size: 14))
    .padding(.horizontal, 5).padding(.top, 6).padding(.bottom, 5)
    .contentShape(Rectangle())
    .dropDestination(for: String.self) { items, _ in
      return acceptDrop(items, before: nil, today: today)
    }
  }

  private func taskRow(_ note: InboxNote) -> some View {
    InboxTaskRow(title: note.body, completed: local.completed.contains(note.id)) {
      if !local.completed.insert(note.id).inserted { local.completed.remove(note.id) }
    } remove: {
      pendingDeletion = note
      confirmDeletion = true
    } save: { value in
      guard !isLoading && !isMutating else { return false }
      editError = nil
      await changeNote(note, body: value)
      if let editError { errorMessage = editError; return false }
      return true
    }
    .draggable("dailyglow-inbox:" + note.id.uuidString)
    .dropDestination(for: String.self) { items, _ in
      return acceptCategorizedDrop(items, before: note.id, category: local.categories?[note.id.uuidString], today: local.todayIDs?.contains(note.id) ?? false)
    } isTargeted: { targeted in
      if targeted { dropTarget = note.id } else if dropTarget == note.id { dropTarget = nil }
    }
    .overlay(alignment: .top) {
      if dropTarget == note.id {
        Capsule().fill(.yellow).frame(height: 3).offset(y: -4)
      }
    }
    .contextMenu {
      Button("Edit…") {
        beginEditing(note)
      }.disabled(isLoading || isMutating)
      Button((local.todayIDs?.contains(note.id) ?? false) ? "Move to Inbox" : "Move to Today") {
        setToday(note.id, today: !(local.todayIDs?.contains(note.id) ?? false))
      }
      ForEach(["Inbox", "Work", "Life"], id: \.self) { category in
        Button("Move to " + category) { setCategory(note.id, category: category == "Inbox" ? nil : category) }
      }
      Button("Move up") { move(note.id, by: -1) }
        .disabled(allTasks.first?.id == note.id)
      Button("Move down") { move(note.id, by: 1) }
        .disabled(allTasks.last?.id == note.id)
      Divider()
      Button("Delete…", role: .destructive) {
        pendingDeletion = note
        confirmDeletion = true
      }.disabled(isLoading || isMutating)
    }
    .accessibilityAction(named: "Move up") { move(note.id, by: -1) }
    .accessibilityAction(named: "Move down") { move(note.id, by: 1) }
    .accessibilityAction(named: "Edit task") { beginEditing(note) }
  }

  private func beginEditing(_ note: InboxNote) {
    guard !isLoading && !isMutating else { return }
    editBody = note.body
    editError = nil
    editingNote = note
  }

  private func isLocal(_ id: UUID) -> Bool {
    local.drafts.contains { $0.id == id }
  }

  private func addTask(today: Bool) {
    let title = (today ? todayTask : newTask).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }
    let id = UUID()
    local.order = allTasks.map(\.id) + [id]
    local.drafts.append(.init(id: id, body: title))
    setToday(id, today: today)
    if today {
      todayTask = ""
      addingTodayTask = true
    } else {
      newTask = ""
      addingTask = true
    }
  }

  private func acceptDrop(_ items: [String], before target: UUID?, today: Bool) -> Bool {
    guard let value = items.first, value.hasPrefix("dailyglow-inbox:"),
      let id = UUID(uuidString: String(value.dropFirst("dailyglow-inbox:".count))),
      id != target, allTasks.contains(where: { $0.id == id })
    else { return false }
    var ids = allTasks.map(\.id)
    ids.removeAll { $0 == id }
    let index = target.flatMap { ids.firstIndex(of: $0) } ?? ids.endIndex
    ids.insert(id, at: index)
    local.order = ids
    setToday(id, today: today)
    dropTarget = nil
    return true
  }

  private func setToday(_ id: UUID, today: Bool) {
    var ids = local.todayIDs ?? []
    if today { ids.insert(id) } else { ids.remove(id) }
    local.todayIDs = ids
    local.categories?[id.uuidString] = nil
  }

  private func move(_ id: UUID, by offset: Int) {
    let today = local.todayIDs?.contains(id) ?? false
    let peers = allTasks.filter { (local.todayIDs?.contains($0.id) ?? false) == today && local.categories?[$0.id.uuidString] == local.categories?[id.uuidString] }.filter {
      local.completed.contains($0.id) == local.completed.contains(id)
    }.map(\.id)
    guard let index = peers.firstIndex(of: id), peers.indices.contains(index + offset) else {
      return
    }
    var ids = allTasks.map(\.id)
    guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: peers[index + offset])
    else { return }
    ids.swapAt(from, to)
    local.order = ids
  }

  private func connect() {
    do {
      let secret = draftSecret.trimmingCharacters(in: .whitespacesAndNewlines)
      if !secret.isEmpty {
        guard secret.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
          throw InboxError.message(
            "Use the 64-character read secret generated with openssl rand -hex 32.")
        }
        try InboxKeychain.save(secret, project: projectURL)
      } else if try InboxKeychain.read(projectURL) == nil {
        throw InboxError.message("Enter a read secret for this project.")
      }
      hasCredential = true
      notes = []
      draftSecret = ""
      showConnection = false
      Task { await refresh() }
    } catch { connectionError = error.localizedDescription }
  }

  private func changeNote(_ note: InboxNote, body: String?) async {
    guard !isMutating && !isLoading else { return }
    if let index = local.drafts.firstIndex(where: { $0.id == note.id }) {
      if let body {
        local.drafts[index].body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        editingNote = nil
      } else {
        local.drafts.remove(at: index)
        local.categories?[note.id.uuidString] = nil
        local.completed.remove(note.id)
        local.todayIDs?.remove(note.id)
        local.order.removeAll { $0 == note.id }
      }
      return
    }
    isMutating = true
    editError = nil
    errorMessage = nil
    defer { isMutating = false }
    do {
      guard let secret = try InboxKeychain.read(projectURL) else {
        throw InboxError.message("Open Settings to enter your inbox secret.")
      }
      var request = URLRequest(
        url: URL(string: projectURL + "/functions/v1/manage-note")!,
        cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
      request.httpMethod = body == nil ? "DELETE" : "PATCH"
      request.setValue(secret, forHTTPHeaderField: "x-read-secret")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      var payload = ["id": note.id.uuidString]
      if let body { payload["body"] = body }
      request.httpBody = try JSONEncoder().encode(payload)
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        throw InboxError.message("No response from Supabase.")
      }
      guard response.statusCode == 200 else {
        let message =
          switch response.statusCode {
          case 401, 403: "Access denied. Check the inbox secret and JWT verification setting."
          case 404:
            "The note was not found, or manage-note has not been deployed. Refresh the inbox."
          case 422: "Enter a note between 1 and 10,000 characters."
          default: "Could not change the note (HTTP \(response.statusCode))."
          }
        throw InboxError.message(message)
      }
      if body != nil {
        struct UpdatedNote: Decodable { let note: InboxNote }
        let updated = try JSONDecoder().decode(UpdatedNote.self, from: data).note
        if let index = notes.firstIndex(where: { $0.id == note.id }) { notes[index] = updated }
        editingNote = nil
      } else {
        notes.removeAll { $0.id == note.id }
        local.categories?[note.id.uuidString] = nil
        local.completed.remove(note.id)
        local.todayIDs?.remove(note.id)
        local.order.removeAll { $0 == note.id }
      }
    } catch {
      let message =
        error.localizedDescription
        + " Refresh to confirm the latest saved state if the request timed out."
      if body != nil { editError = message } else { errorMessage = message }
    }
  }

  private func refresh() async {
    guard !isLoading && !isMutating else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      guard let secret = try InboxKeychain.read(projectURL) else {
        hasCredential = false
        return
      }
      hasCredential = true
      guard let url = URL(string: projectURL + "/functions/v1/read-notes") else { return }
      var request = URLRequest(
        url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
      request.setValue(secret, forHTTPHeaderField: "x-read-secret")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        throw InboxError.message("No response from Supabase.")
      }
      guard response.statusCode == 200 else {
        let message =
          switch response.statusCode {
          case 401, 403:
            "Access denied. Check the read secret and the function's JWT verification setting."
          case 404: "Deploy the read-notes function in this Supabase project first."
          default: "Could not load notes (HTTP \(response.statusCode)). Try refreshing."
          }
        throw InboxError.message(message)
      }
      let incoming = try JSONDecoder().decode(InboxResponse.self, from: data).notes
      let known = Set(local.order)
      local.order = incoming.map(\.id).filter { !known.contains($0) } + local.order
      notes = incoming
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#if DEBUG
  #Preview("Inbox Panel") {
    InboxPanelView().frame(width: 320, height: 600)
  }
#endif

