"use client";
import { Canvas } from "@react-three/fiber";
import { MindSphere } from "./MindSphere";
import { StressParticles } from "./StressParticles";

export function Scene({ isCalm }: { isCalm: boolean }) {
  return (
    <div className="fixed inset-0 z-0 pointer-events-none">
      <Canvas
        camera={{ position: [0, 0, 5], fov: 45 }}
        style={{ pointerEvents: "auto" }} // Allow mouse events for interactive rotation
        gl={{ antialias: true, alpha: true }}
      >
        <ambientLight intensity={1.5} />
        <pointLight position={[10, 10, 10]} intensity={2} color="#ffffff" />
        <pointLight position={[-10, -10, -10]} intensity={1} color="#4f46e5" />
        
        <MindSphere isCalm={isCalm} />
        <StressParticles isCalm={isCalm} />
      </Canvas>
    </div>
  );
}
