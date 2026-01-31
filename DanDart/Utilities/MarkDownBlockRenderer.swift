//
//  MarkDownBlockRenderer.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-01-18.
//

import SwiftUI

/// Reusable renderer for simple, policy-style Markdown files bundled with the app.
/// Supports: # / ## / ### headings, paragraphs, and `-` bullet lists.
struct MarkDownBlockRenderer: View {
    let title: String
    let markdownFileName: String

    @State private var blocks: [PolicyMarkdownBlock] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if blocks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.justWhite)
                        Text("We couldn’t load the text.")
                            .font(.body)
                            .foregroundStyle(AppColor.textSecondary)
                        Text("Please try again later.")
                            .font(.body)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                } else {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .h1(let text):
                            Text(text)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                                .foregroundStyle(AppColor.justWhite)

                        case .h2(let text):
                            Text(text)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                                .foregroundStyle(AppColor.justWhite)

                        case .h3(let text):
                            Text(text)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                                .foregroundStyle(AppColor.justWhite)

                        case .paragraph(let text):
                            Text(text)
                                .font(.body)
                                .foregroundStyle(AppColor.textSecondary)

                        case .italic(let text):
                            Text(text)
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(AppColor.textSecondary)

                        case .bullets(let items):
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(items, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("•")
                                            .font(.body)
                                            .foregroundStyle(AppColor.textSecondary)
                                        Text(item)
                                            .font(.body)
                                            .foregroundStyle(AppColor.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if blocks.isEmpty {
                blocks = loadAndParseMarkdownFromBundle(named: markdownFileName)
            }
        }
    }

    private func loadAndParseMarkdownFromBundle(named name: String) -> [PolicyMarkdownBlock] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "md") else {
            return []
        }

        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            return parseMarkdown(markdown)
        } catch {
            return []
        }
    }

    private func parseMarkdown(_ markdown: String) -> [PolicyMarkdownBlock] {
        var result: [PolicyMarkdownBlock] = []

        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var currentParagraphLines: [String] = []
        var currentBullets: [String] = []

        func flushParagraphIfNeeded() {
            let text = currentParagraphLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !text.isEmpty {
                // Detect simple italic line like: _Last updated: ..._
                if text.hasPrefix("_") && text.hasSuffix("_") && text.count >= 2 {
                    let inner = String(text.dropFirst().dropLast())
                    result.append(.italic(inner))
                } else {
                    result.append(.paragraph(text))
                }
            }
            currentParagraphLines.removeAll()
        }

        func flushBulletsIfNeeded() {
            if !currentBullets.isEmpty {
                result.append(.bullets(currentBullets))
            }
            currentBullets.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Blank line ends current paragraph / list
            if line.isEmpty {
                flushBulletsIfNeeded()
                flushParagraphIfNeeded()
                continue
            }

            // Headings
            if line.hasPrefix("# ") {
                flushBulletsIfNeeded()
                flushParagraphIfNeeded()
                result.append(.h1(String(line.dropFirst(2))))
                continue
            }
            if line.hasPrefix("## ") {
                flushBulletsIfNeeded()
                flushParagraphIfNeeded()
                result.append(.h2(String(line.dropFirst(3))))
                continue
            }
            if line.hasPrefix("### ") {
                flushBulletsIfNeeded()
                flushParagraphIfNeeded()
                result.append(.h3(String(line.dropFirst(4))))
                continue
            }

            // Unordered list item
            if line.hasPrefix("- ") {
                flushParagraphIfNeeded()
                currentBullets.append(String(line.dropFirst(2)))
                continue
            }

            // Normal paragraph line
            flushBulletsIfNeeded()
            currentParagraphLines.append(line)
        }

        flushBulletsIfNeeded()
        flushParagraphIfNeeded()

        return result
    }
}

enum PolicyMarkdownBlock {
    case h1(String)
    case h2(String)
    case h3(String)
    case italic(String)
    case paragraph(String)
    case bullets([String])
}

#Preview {
    NavigationStack {
        MarkDownBlockRenderer(title: "Privacy Policy", markdownFileName: "PrivacyPolicy")
    }
}
