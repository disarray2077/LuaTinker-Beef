import { useEffect, useLayoutEffect, useRef } from "react";
import { createPortal } from "react-dom";

export function ActionMenu({ anchor, label, items, onClose }) {
  const menu = useRef(null);
  useLayoutEffect(() => {
    const element = menu.current;
    const { width, height } = element.getBoundingClientRect();
    const left = anchor.alignRight ? anchor.x - width : anchor.x;
    element.style.left = `${Math.max(8, Math.min(left, window.innerWidth - width - 8))}px`;
    element.style.top = `${Math.max(8, Math.min(anchor.y, window.innerHeight - height - 8))}px`;
    (element.querySelector("button:not(:disabled)") || element).focus();
  }, [anchor]);
  useEffect(() => {
    function outside(event) {
      if (
        !menu.current.contains(event.target) &&
        !anchor.trigger.contains(event.target)
      )
        onClose(false);
    }
    function scroll(event) {
      if (!menu.current.contains(event.target)) onClose(false);
    }
    const resize = () => onClose(false);
    document.addEventListener("pointerdown", outside, true);
    document.addEventListener("scroll", scroll, true);
    window.addEventListener("resize", resize);
    return () => {
      document.removeEventListener("pointerdown", outside, true);
      document.removeEventListener("scroll", scroll, true);
      window.removeEventListener("resize", resize);
    };
  }, [anchor, onClose]);

  return createPortal(
    <div
      ref={menu}
      className="action-menu"
      role="menu"
      tabIndex={-1}
      aria-label={label}
      onKeyDown={(event) => {
        if (event.key === "Escape" || event.key === "Tab") {
          if (event.key === "Escape") event.preventDefault();
          event.stopPropagation();
          onClose();
          return;
        }
        const buttons = [
          ...menu.current.querySelectorAll("button:not(:disabled)"),
        ];
        const current = buttons.indexOf(document.activeElement);
        let next;
        switch (event.key) {
          case "ArrowDown":
            next = (current + 1) % buttons.length;
            break;
          case "ArrowUp":
            next = (current - 1 + buttons.length) % buttons.length;
            break;
          case "Home":
            next = 0;
            break;
          case "End":
            next = buttons.length - 1;
            break;
          default:
            return;
        }
        event.preventDefault();
        buttons[next]?.focus();
      }}
    >
      {items.map((item) => (
        <button
          key={item.label}
          type="button"
          role="menuitem"
          tabIndex={-1}
          disabled={item.disabled}
          className={item.danger ? "danger" : undefined}
          onClick={() => {
            onClose();
            item.action();
          }}
        >
          {item.label}
        </button>
      ))}
    </div>,
    document.body,
  );
}
