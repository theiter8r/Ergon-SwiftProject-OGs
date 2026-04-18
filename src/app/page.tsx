"use client";

import { useState, useEffect } from "react";
import { Scene } from "@/components/Scene";
import { Hero } from "@/components/Hero";
import { FeatureCards } from "@/components/FeatureCards";
import { Footer } from "@/components/Footer";

export default function Home() {
  const [isCalm, setIsCalm] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      // If we are calm and they scroll far enough down, break calm
      if (isCalm && window.scrollY > 150) {
        setIsCalm(false);
      }
    };

    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, [isCalm]);

  const handleStartRoutine = () => {
    setIsCalm(true);

    // Smooth scroll to top
    window.scrollTo({
      top: 0,
      behavior: "smooth"
    });
  };

  return (
    <main className="relative min-h-screen bg-transparent selection:bg-indigo-500/30">
      {/* Background Video Layer */}
      <div className="fixed inset-0 z-[-2] w-full h-full overflow-hidden bg-[#000005]">
        <video
          autoPlay
          loop
          muted
          playsInline
          className="absolute inset-0 w-full h-full object-cover opacity-[0.4]"
        >
          <source
            src="./bgvideo.mp4"
            type="video/mp4"
          />
        </video>
        {/* Dark Gradient Overlay & slight blur over video */}
        <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-[#000005] backdrop-blur-[2px]" />
      </div>

      {/* 3D Scene Layer (Middle) */}
      <div className="fixed inset-0 z-[-1] pointer-events-none">
        <Scene isCalm={isCalm} />
      </div>

      {/* Foreground Content */}
      <div className="relative z-10 w-full flex flex-col">
        <Hero onStartRoutine={handleStartRoutine} />

        <div className="pt-16 pb-24 bg-gradient-to-b from-transparent to-[#000005]">
          <FeatureCards />
        </div>
        
        <Footer />
      </div>
    </main>
  );
}
