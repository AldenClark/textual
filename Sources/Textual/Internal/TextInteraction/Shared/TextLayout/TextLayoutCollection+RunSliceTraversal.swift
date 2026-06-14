#if TEXTUAL_ENABLE_TEXT_SELECTION
  import Foundation

  extension TextLayoutCollection {
    func indexPathsForRunSlices(in range: TextRange) -> some Sequence<IndexPath> {
      IndexPathSequence(
        range: range,
        next: self.indexPathForRunSlice(after:),
        previous: self.indexPathForRunSlice(before:)
      )
    }
  }

  extension TextLayoutCollection {
    fileprivate func indexPathForRunSlice(after indexPath: IndexPath) -> IndexPath? {
      guard
        let layout = layout(at: indexPath.layout),
        let line = layout.lines[safe: indexPath.line],
        let run = line.runs[safe: indexPath.run]
      else {
        return nil
      }

      if indexPath.runSlice + 1 < run.slices.count {
        return IndexPath(
          runSlice: indexPath.runSlice + 1,
          run: indexPath.run,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.run + 1 < line.runs.count {
        return IndexPath(
          run: indexPath.run + 1,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.line + 1 < layout.lines.count {
        return IndexPath(
          line: indexPath.line + 1,
          layout: indexPath.layout
        )
      }

      if indexPath.layout + 1 < layouts.count {
        return IndexPath(layout: indexPath.layout + 1)
      }

      return nil
    }

    fileprivate func indexPathForRunSlice(before indexPath: IndexPath) -> IndexPath? {
      if indexPath.runSlice > 0 {
        return IndexPath(
          runSlice: indexPath.runSlice - 1,
          run: indexPath.run,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.run > 0 {
        guard
          let line = line(at: indexPath),
          let previousRun = line.runs[safe: indexPath.run - 1]
        else {
          return nil
        }
        return IndexPath(
          runSlice: previousRun.slices.endIndex - 1,
          run: indexPath.run - 1,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.line > 0 {
        guard
          let layout = layout(at: indexPath.layout),
          let previousLine = layout.lines[safe: indexPath.line - 1]
        else {
          return nil
        }
        let lastRunIndex = previousLine.runs.endIndex - 1
        guard let lastRun = previousLine.runs[safe: lastRunIndex] else {
          return nil
        }

        return IndexPath(
          runSlice: lastRun.slices.endIndex - 1,
          run: lastRunIndex,
          line: indexPath.line - 1,
          layout: indexPath.layout
        )
      }

      if indexPath.layout > 0 {
        guard let previousLayout = layout(at: indexPath.layout - 1) else {
          return nil
        }
        let lastLineIndex = previousLayout.lines.endIndex - 1
        guard let lastLine = previousLayout.lines[safe: lastLineIndex] else {
          return nil
        }
        let lastRunIndex = lastLine.runs.endIndex - 1
        guard let lastRun = lastLine.runs[safe: lastRunIndex] else {
          return nil
        }
        return IndexPath(
          runSlice: lastRun.slices.endIndex - 1,
          run: lastRunIndex,
          line: lastLineIndex,
          layout: indexPath.layout - 1
        )
      }

      return nil
    }
  }
#endif
