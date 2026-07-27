import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { SdImportVisual } from "./sd-import-visual";

describe("SdImportVisual", () => {
  it("renders a detailed SD card and a photo transfer path", () => {
    render(<SdImportVisual />);

    const visual = screen.getByTestId("sd-import-visual");
    expect(visual.querySelector("title")).toHaveTextContent(
      "Photos importing from an SD card",
    );
    expect(screen.getByTestId("sd-card-outline")).toBeInTheDocument();
    expect(screen.getByTestId("sd-card-contacts").children.length).toBeGreaterThan(
      5,
    );
    expect(screen.getByTestId("sd-transfer-path")).toBeInTheDocument();
    expect(screen.getAllByTestId("sd-traveling-photo")).toHaveLength(3);
  });
});
