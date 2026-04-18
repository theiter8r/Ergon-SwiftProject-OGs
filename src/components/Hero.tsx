import { ArrowRight } from "lucide-react";

interface HeroProps {
  onStartRoutine: () => void;
}

export function Hero({ onStartRoutine }: HeroProps) {
  return (
    <div className="relative z-10 flex flex-col items-center justify-center min-h-[100vh] px-6 text-center">
      <h1 className="font-serif font-normal text-6xl md:text-8xl leading-tight tracking-normal mb-8 text-white drop-shadow-[0_0_20px_rgba(255,255,255,0.4)]">
        Burnout doesn't happen overnight.
      </h1>
      <p className="text-lg md:text-2xl text-zinc-300 max-w-2xl mb-12 drop-shadow">
        Track patterns. Detect early. Recover smarter.
      </p>
      
      <button
        onClick={onStartRoutine}
        className="group relative flex items-center gap-3 px-8 py-4 bg-white/10 hover:bg-white/20 border border-white/20 rounded-full transition-all duration-300 ease-out backdrop-blur-md overflow-hidden text-lg font-medium"
      >
        <span className="relative z-10">Start Your Day</span>
        <ArrowRight className="w-5 h-5 relative z-10 group-hover:translate-x-1 transition-transform" />
        <div className="absolute inset-0 bg-gradient-to-r from-blue-500/20 to-purple-500/20 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
      </button>
      
      {/* Scroll indicator */}
      <div className="absolute bottom-10 animate-bounce text-white/50">
        <p className="text-sm tracking-widest uppercase mb-2">Scroll to explore</p>
        <div className="w-px h-12 bg-gradient-to-b from-white/50 to-transparent mx-auto" />
      </div>
    </div>
  );
}
