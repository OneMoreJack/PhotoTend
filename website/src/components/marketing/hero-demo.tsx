"use client";

import type { Locale } from "@/i18n/config";
import type { CSSProperties, PointerEvent as ReactPointerEvent } from "react";
import { useEffect, useRef, useState } from "react";

type Action = "idle" | "next" | "trash" | "undo";

const scenes = [
  {
    date: "杭州 · 2026.04.18",
    sun: "#f4c86f",
    sky: "#dca77d",
    ridge: "#9b6846",
    foreground: "#4f2d24",
  },
  {
    date: "京都 · 2025.11.02",
    sun: "#f7dcc1",
    sky: "#9a5942",
    ridge: "#713b31",
    foreground: "#2a2524",
  },
  {
    date: "青海 · 2024.08.16",
    sun: "#f6e4b1",
    sky: "#8aa3a0",
    ridge: "#5e7770",
    foreground: "#263c3a",
  },
] as const;

const statusCopy = {
  "zh-CN": {
    label: "PhotoTend 手势操作演示",
    idle: "拖动照片，体验 PhotoTend 手势",
    next: "已切换到下一张照片",
    trash: "已移入回收站",
    undo: "已撤销刚才的操作",
    hint: "拖动试试",
    trashLabel: "回收站",
    undoLabel: "已撤销",
  },
  en: {
    label: "Interactive PhotoTend gesture demo",
    idle: "Drag the photo to try PhotoTend gestures",
    next: "Moved to the next photo",
    trash: "Moved to trash",
    undo: "Last action undone",
    hint: "Try dragging",
    trashLabel: "Trash",
    undoLabel: "Undone",
  },
} as const;

const threshold = 56;

export function HeroDemo({ locale }: { locale: Locale }) {
  const copy = statusCopy[locale];
  const [sceneIndex, setSceneIndex] = useState(0);
  const [action, setAction] = useState<Action>("idle");
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [dragging, setDragging] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);
  const drag = useRef({
    pointerId: -1,
    startX: 0,
    startY: 0,
    x: 0,
    y: 0,
  });
  const interactionPauseUntil = useRef(0);
  const autoStep = useRef(0);

  useEffect(() => {
    const media = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    if (!media) return;

    const update = () => setReducedMotion(media.matches);
    update();
    media.addEventListener?.("change", update);
    return () => media.removeEventListener?.("change", update);
  }, []);

  useEffect(() => {
    if (reducedMotion) return;

    const timer = window.setInterval(() => {
      if (dragging || Date.now() < interactionPauseUntil.current) return;

      const sequence: Action[] = ["next", "trash", "undo"];
      const nextAction = sequence[autoStep.current % sequence.length]!;
      autoStep.current += 1;
      completeAction(nextAction);
    }, 2800);

    return () => window.clearInterval(timer);
  }, [dragging, reducedMotion]);

  function completeAction(nextAction: Action) {
    setAction(nextAction);
    setOffset({ x: 0, y: 0 });
    if (nextAction === "next") {
      setSceneIndex((current) => (current + 1) % scenes.length);
    } else if (nextAction === "undo") {
      setSceneIndex((current) => (current - 1 + scenes.length) % scenes.length);
    }
  }

  function handlePointerDown(event: ReactPointerEvent<HTMLDivElement>) {
    event.currentTarget.setPointerCapture?.(event.pointerId);
    drag.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      x: 0,
      y: 0,
    };
    setDragging(true);
    setAction("idle");
  }

  function handlePointerMove(event: ReactPointerEvent<HTMLDivElement>) {
    if (!dragging || drag.current.pointerId !== event.pointerId) return;

    const rawX = event.clientX - drag.current.startX;
    const rawY = event.clientY - drag.current.startY;
    const horizontal = Math.abs(rawX) > Math.abs(rawY);
    const x = horizontal ? rawX : 0;
    const y = horizontal ? 0 : rawY;
    drag.current.x = x;
    drag.current.y = y;
    setOffset({ x, y });
  }

  function handlePointerUp(event: ReactPointerEvent<HTMLDivElement>) {
    if (drag.current.pointerId !== event.pointerId) return;

    const { x, y } = drag.current;
    setDragging(false);
    interactionPauseUntil.current = Date.now() + 4500;

    if (Math.abs(x) >= threshold) {
      completeAction("next");
    } else if (y <= -threshold) {
      completeAction("trash");
    } else if (y >= threshold) {
      completeAction("undo");
    } else {
      setAction("idle");
      setOffset({ x: 0, y: 0 });
    }
  }

  const cardStyle = {
    "--drag-x": `${offset.x}px`,
    "--drag-y": `${offset.y}px`,
  } as CSSProperties;

  return (
    <div className="hero-demo">
      <div className="hero-demo__backdrop" aria-hidden="true" />
      <div
        className="hero-demo__phone"
        data-action={action}
        data-dragging={dragging ? "true" : "false"}
        data-reduced-motion={reducedMotion ? "true" : "false"}
      >
        <div className="hero-demo__statusbar" aria-hidden="true">
          <span>9:41</span>
          <span>● ●●</span>
        </div>
        <div
          className="hero-demo__viewport"
          aria-label={copy.label}
          data-gesture-surface
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
        >
          <div
            className="hero-demo__trash"
            data-visible={action === "trash" ? "true" : "false"}
            aria-hidden="true"
          >
            <span>↑</span>
            {copy.trashLabel}
          </div>
          <div
            className="hero-demo__card"
            data-testid="hero-photo-card"
            style={cardStyle}
          >
            {scenes.map((scene, index) => (
              <svg
                className="hero-demo__scene"
                data-active={index === sceneIndex ? "true" : "false"}
                data-testid="hero-photo-scene"
                key={scene.date}
                viewBox="0 0 360 470"
                aria-hidden="true"
              >
                <rect width="360" height="470" fill={scene.sky} />
                <circle cx="270" cy="108" r="42" fill={scene.sun} />
                <path
                  d="M0 244 Q95 172 188 218 T360 218 V470 H0Z"
                  fill={scene.ridge}
                />
                <path
                  d="M0 330 Q118 250 232 312 T360 308 V470 H0Z"
                  fill={scene.foreground}
                />
              </svg>
            ))}
            <span className="hero-demo__date">
              {scenes[sceneIndex]!.date}
            </span>
          </div>
        </div>
        <div className="hero-demo__controls" aria-hidden="true">
          <span>←</span>
          <span>↑</span>
          <span>↓</span>
          <span>→</span>
        </div>
        <div className="hero-demo__thumbs" aria-hidden="true">
          {scenes.map((scene, index) => (
            <span
              key={scene.date}
              data-active={index === sceneIndex ? "true" : "false"}
              style={{ background: scene.sky }}
            />
          ))}
        </div>
      </div>
      <div className="hero-demo__hint" aria-hidden="true">
        {copy.hint} <span>↗</span>
      </div>
      <div
        className="hero-demo__undo"
        data-visible={action === "undo" ? "true" : "false"}
        aria-hidden="true"
      >
        {copy.undoLabel}
      </div>
      <p className="sr-only" role="status" aria-live="polite">
        {copy[action]}
      </p>
    </div>
  );
}
