import Link from "next/link";

export default function HomePage() {
  return (
    <main>
      <h1>理好相册 PhotoTend</h1>
      <p>轻松整理，留下真正重要的照片。</p>
      <Link href="/api/download/android?locale=zh-CN">下载 Android 版</Link>
    </main>
  );
}
