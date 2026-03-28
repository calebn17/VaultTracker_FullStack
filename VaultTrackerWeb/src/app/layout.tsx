import type { Metadata } from "next";
import { DM_Mono, Geist, Geist_Mono, Instrument_Serif, Syne } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers";

const geistSans = Geist({
  variable: "--font-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const instrumentSerif = Instrument_Serif({
  weight: "400",
  subsets: ["latin"],
  variable: "--font-meridian-serif",
  display: "swap",
});

const dmMono = DM_Mono({
  weight: ["400", "500"],
  subsets: ["latin"],
  variable: "--font-meridian-mono",
  display: "swap",
});

const syne = Syne({
  weight: ["400", "600", "700"],
  subsets: ["latin"],
  variable: "--font-meridian-syne",
  display: "swap",
});

export const metadata: Metadata = {
  title: "VaultTracker",
  description: "Personal net worth dashboard",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} ${instrumentSerif.variable} ${dmMono.variable} ${syne.variable} flex min-h-full flex-col font-sans antialiased`}
      >
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
