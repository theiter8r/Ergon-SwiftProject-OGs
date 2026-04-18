import { Moon, Sun, Activity, BrainCircuit } from "lucide-react";

export function FeatureCards() {
  const cards = [
    {
      title: "Guided Routines",
      description: "Seamless transitions between your morning focus and evening wind-down to maintain balance.",
      icon: <div className="flex gap-2"><Sun className="w-6 h-6 text-yellow-400" /><Moon className="w-6 h-6 text-indigo-400" /></div>,
      gradient: "from-yellow-500/10 to-indigo-500/10"
    },
    {
      title: "Pattern Detection",
      description: "Passive monitoring of your work habits to detect the subtle signs of impending peak stress.",
      icon: <Activity className="w-8 h-8 text-rose-400" />,
      gradient: "from-rose-500/10 to-orange-500/10"
    },
    {
      title: "Smart Insights",
      description: "Actionable recommendations tailored to your unique cognitive load and recovery needs.",
      icon: <BrainCircuit className="w-8 h-8 text-emerald-400" />,
      gradient: "from-emerald-500/10 to-blue-500/10"
    }
  ];

  return (
    <div className="relative z-10 max-w-7xl mx-auto px-6 py-24 min-h-screen flex items-center">
      <div className="w-full">
        <div className="text-center mb-16">
          <h2 className="font-serif font-normal text-5xl md:text-6xl mb-4 text-white drop-shadow-lg">Restore your equilibrium</h2>
          <p className="text-zinc-400 text-lg max-w-2xl mx-auto">
            Our system works quietly in the background, ensuring you step away before the pressure builds up.
          </p>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {cards.map((card, idx) => (
            <div 
              key={idx}
              className="glass-card rounded-3xl p-8 hover:-translate-y-2 transition-transform duration-300 relative overflow-hidden group"
            >
              <div className={`absolute inset-0 bg-gradient-to-br ${card.gradient} opacity-50 group-hover:opacity-100 transition-opacity duration-300`} />
              
              <div className="relative z-10 flex flex-col h-full">
                <div className="mb-6 p-4 bg-black/20 w-fit rounded-2xl border border-white/5">
                  {card.icon}
                </div>
                <h3 className="font-serif font-normal text-3xl md:text-4xl mb-3 text-white">{card.title}</h3>
                <p className="text-zinc-400 leading-relaxed flex-grow">
                  {card.description}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
