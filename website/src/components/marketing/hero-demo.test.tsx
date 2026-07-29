import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { HeroDemo } from "./hero-demo";

describe("HeroDemo", () => {
  it("renders a localized, pointer-draggable PhotoTend interface", () => {
    render(<HeroDemo locale="zh-CN" />);

    const surface = screen.getByLabelText("PhotoTend 手势操作演示");
    expect(surface).toHaveAttribute("data-gesture-surface");
    expect(screen.getByTestId("hero-photo-card")).toBeVisible();
    expect(screen.getAllByTestId("hero-photo-scene")).toHaveLength(3);
    expect(screen.getByRole("status")).toHaveTextContent(
      "拖动照片，体验 PhotoTend 手势",
    );
  });

  it("completes a left swipe and announces the next photo", () => {
    render(<HeroDemo locale="zh-CN" />);
    const surface = screen.getByLabelText("PhotoTend 手势操作演示");

    fireEvent.pointerDown(surface, {
      pointerId: 1,
      clientX: 240,
      clientY: 200,
    });
    fireEvent.pointerMove(surface, {
      pointerId: 1,
      clientX: 140,
      clientY: 202,
    });
    fireEvent.pointerUp(surface, {
      pointerId: 1,
      clientX: 140,
      clientY: 202,
    });

    expect(screen.getByRole("status")).toHaveTextContent("已切换到下一张照片");
  });

  it("completes upward trash and ignores a downward drag", () => {
    render(<HeroDemo locale="zh-CN" />);
    const surface = screen.getByLabelText("PhotoTend 手势操作演示");

    fireEvent.pointerDown(surface, {
      pointerId: 2,
      clientX: 180,
      clientY: 260,
    });
    fireEvent.pointerMove(surface, {
      pointerId: 2,
      clientX: 182,
      clientY: 150,
    });
    fireEvent.pointerUp(surface, {
      pointerId: 2,
      clientX: 182,
      clientY: 150,
    });
    expect(screen.getByRole("status")).toHaveTextContent("已移入回收站");

    fireEvent.pointerDown(surface, {
      pointerId: 3,
      clientX: 180,
      clientY: 150,
    });
    fireEvent.pointerMove(surface, {
      pointerId: 3,
      clientX: 180,
      clientY: 250,
    });
    fireEvent.pointerUp(surface, {
      pointerId: 3,
      clientX: 180,
      clientY: 250,
    });
    expect(screen.getByRole("status")).toHaveTextContent(
      "拖动照片，体验 PhotoTend 手势",
    );
    expect(screen.queryByText("已撤销")).not.toBeInTheDocument();
  });
});
