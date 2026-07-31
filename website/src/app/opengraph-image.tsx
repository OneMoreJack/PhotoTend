import { ImageResponse } from "next/og";

export const dynamic = "force-static";
export const alt = "理好相册 PhotoTend — 轻松整理，留下真正重要的照片";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: "72px 88px",
          background: "#f4f0e8",
          color: "#171a1c",
          fontFamily: "sans-serif",
        }}
      >
        <div
          style={{
            width: 680,
            display: "flex",
            flexDirection: "column",
            gap: 28,
          }}
        >
          <div
            style={{
              display: "flex",
              color: "#7e351f",
              fontSize: 24,
              fontWeight: 700,
              letterSpacing: "0.12em",
            }}
          >
            PHOTOTEND · 理好相册
          </div>
          <div
            style={{
              display: "flex",
              fontSize: 76,
              fontWeight: 800,
              letterSpacing: "-0.06em",
              lineHeight: 1.04,
            }}
          >
            轻松整理，
            <br />
            留下真正重要的照片。
          </div>
          <div style={{ display: "flex", color: "#69635b", fontSize: 28 }}>
            手势整理 · 安全回收站 · 外部照片导入
          </div>
        </div>
        <div
          style={{
            width: 300,
            height: 430,
            display: "flex",
            alignItems: "flex-end",
            padding: 24,
            border: "10px solid #171a1c",
            borderRadius: 52,
            background:
              "linear-gradient(150deg, #d9b68f 0%, #8e5b3f 50%, #20201f 100%)",
            boxShadow: "22px 26px 0 #a64b28",
          }}
        >
          <div
            style={{
              display: "flex",
              padding: "12px 18px",
              borderRadius: 999,
              background: "#fffcf6",
              color: "#7e351f",
              fontSize: 20,
              fontWeight: 700,
            }}
          >
            一划，理好一张
          </div>
        </div>
      </div>
    ),
    size,
  );
}
