import Link from "next/link";

export function Footer() {
  return (
    <footer className="relative w-full overflow-hidden bg-black/80 backdrop-blur-md border-t border-white/10 pt-16 pb-8 px-6 text-white z-20">
      
      {/* Background Soft Green Gradient / Particle Texture */}
      <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[600px] h-[300px] bg-green-500/10 blur-[100px] rounded-full pointer-events-none" />
      <div 
        className="absolute inset-0 opacity-[0.04] pointer-events-none mix-blend-screen"
        style={{ backgroundImage: "radial-gradient(circle at center, white 1px, transparent 1px)", backgroundSize: "24px 24px" }}
      />
      
      <div className="relative max-w-7xl mx-auto z-10 flex flex-col md:flex-row justify-between gap-12 md:gap-4 border-b border-white/5 pb-12">
        {/* Left Side: Brand */}
        <div className="flex flex-col">
          <span className="font-serif text-4xl tracking-wide select-none">Ergon</span>
          <p className="mt-4 text-zinc-400 text-sm max-w-xs leading-relaxed">
            Intelligent burnout detection and cognitive tracking for the modern mind.
          </p>
        </div>

        {/* Right Side: Links */}
        <div className="flex flex-col sm:flex-row gap-12 sm:gap-24">
          {/* Explore Section */}
          <div className="flex flex-col gap-5">
            <h4 className="text-xs font-semibold text-zinc-500 uppercase tracking-widest">Explore</h4>
            <Link href="https://github.com/theiter8r/Ergon-SwiftProject-OGs" className="text-zinc-300 hover:text-white transition-colors duration-300 text-sm inline-flex">GitHub</Link>
            <Link href="#" className="text-zinc-300 hover:text-white transition-colors duration-300 text-sm inline-flex">Demo</Link>
          </div>

          {/* Legal Section */}
          <div className="flex flex-col gap-5">
            <h4 className="text-xs font-semibold text-zinc-500 uppercase tracking-widest">Legal</h4>
            <Link href="#" className="text-zinc-300 hover:text-white transition-colors duration-300 text-sm inline-flex">Terms</Link>
            <Link href="#" className="text-zinc-300 hover:text-white transition-colors duration-300 text-sm inline-flex">Privacy</Link>
          </div>
        </div>
      </div>
      
      {/* Copyright */}
      <div className="relative max-w-7xl mx-auto z-10 pt-8 flex flex-col sm:flex-row justify-between items-center gap-4">
        <p className="text-zinc-500 text-sm">
          © {new Date().getFullYear()} Ergon. Built for Hackathon.
        </p>
      </div>
    </footer>
  );
}
