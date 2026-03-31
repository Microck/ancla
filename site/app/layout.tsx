import type { Metadata } from "next";
import "@fontsource-variable/google-sans-flex";
import "./globals.css";

export const metadata: Metadata = {
  title: "Ancla",
  description:
    "Ancla pairs Screen Time blocking with a physical NFC anchor so opening distracting apps takes intent, not just one more tap.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
