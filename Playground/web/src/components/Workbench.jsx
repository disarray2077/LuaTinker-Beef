import { Children, Fragment, useLayoutEffect, useRef, useState } from "react";

const minimumWidths = [160, 240, 240];
const panelIds = ["files-panel", "editor-panel", "preview-panel"];
const labels = ["Resize Files and Code", "Resize Code and Preview"];

function panelWidths(container) {
  return [...container.querySelectorAll(":scope > .pane")].map(
    (pane) => pane.getBoundingClientRect().width,
  );
}

export function Workbench({ children }) {
  const container = useRef(null);
  const drag = useRef(null);
  const [widths, setWidths] = useState(null);
  const [resizing, setResizing] = useState(false);
  useLayoutEffect(() => {
    const observer = new ResizeObserver(() => {
      const measured = panelWidths(container.current);
      if (measured.every((width) => width > 0)) setWidths(measured);
    });
    observer.observe(container.current);
    return () => observer.disconnect();
  }, []);

  function resize(index, initial, delta) {
    const change = Math.max(
      minimumWidths[index] - initial[index],
      Math.min(delta, initial[index + 1] - minimumWidths[index + 1]),
    );
    const next = [...initial];
    next[index] += change;
    next[index + 1] -= change;
    setWidths(next);
  }

  function startDrag(event, index) {
    if (event.button !== 0) return;
    event.preventDefault();
    event.currentTarget.focus();
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = {
      index,
      pointerId: event.pointerId,
      x: event.clientX,
      widths: panelWidths(container.current),
    };
    setResizing(true);
  }

  function endDrag(event) {
    if (drag.current?.pointerId !== event.pointerId) return;
    drag.current = null;
    setResizing(false);
    if (event.currentTarget.hasPointerCapture(event.pointerId))
      event.currentTarget.releasePointerCapture(event.pointerId);
  }

  return (
    <main
      ref={container}
      className={`workbench${resizing ? " resizing" : ""}`}
      style={
        widths && {
          "--files-size": `${widths[0]}fr`,
          "--code-size": `${widths[1]}fr`,
          "--preview-size": `${widths[2]}fr`,
        }
      }
    >
      {Children.toArray(children).map((pane, index) => (
        <Fragment key={pane.key}>
          {pane}
          {index < 2 && (
            <div
              className="panel-divider"
              role="separator"
              tabIndex={0}
              aria-orientation="vertical"
              aria-label={labels[index]}
              aria-controls={`${panelIds[index]} ${panelIds[index + 1]}`}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={
                widths
                  ? Math.round(
                      (100 * widths[index]) /
                        (widths[index] + widths[index + 1]),
                    )
                  : undefined
              }
              onPointerDown={(event) => startDrag(event, index)}
              onPointerMove={(event) => {
                const active = drag.current;
                if (active?.pointerId === event.pointerId)
                  resize(active.index, active.widths, event.clientX - active.x);
              }}
              onPointerUp={endDrag}
              onPointerCancel={endDrag}
              onLostPointerCapture={endDrag}
              onKeyDown={(event) => {
                if (event.key !== "ArrowLeft" && event.key !== "ArrowRight")
                  return;
                event.preventDefault();
                resize(
                  index,
                  panelWidths(container.current),
                  (event.key === "ArrowLeft" ? -1 : 1) *
                    (event.shiftKey ? 64 : 16),
                );
              }}
            />
          )}
        </Fragment>
      ))}
    </main>
  );
}
