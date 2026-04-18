"use client";
import { useRef, useMemo } from "react";
import { useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { useScroll } from "framer-motion";

export function StressParticles({ isCalm }: { isCalm: boolean }) {
  const count = 200;
  const meshRef = useRef<THREE.InstancedMesh>(null);
  
  const { scrollYProgress } = useScroll();

  // Initial positions
  const dummy = useMemo(() => new THREE.Object3D(), []);
  const particles = useMemo(() => {
    const temp = [];
    for (let i = 0; i < count; i++) {
      const x = (Math.random() - 0.5) * 10;
      const y = (Math.random() - 0.5) * 10;
      const z = (Math.random() - 0.5) * 10;
      
      const speed = 0.01 + Math.random() * 0.02;
      temp.push({ x, y, z, speed, initialX: x, initialY: y, initialZ: z });
    }
    return temp;
  }, [count]);

  useFrame((state) => {
    if (!meshRef.current) return;
    
    const time = state.clock.elapsedTime;
    const scrollStress = isCalm ? 0 : scrollYProgress.get() * 1.5;
    const clampedStress = Math.min(Math.max(scrollStress, 0), 1);
    
    // Scale particles based on stress
    const targetScale = clampedStress * 0.1;

    particles.forEach((particle, i) => {
      // Jitter movement when stressed
      const jitterX = Math.sin(time * 10 + i) * clampedStress * 0.2;
      const jitterY = Math.cos(time * 12 + i) * clampedStress * 0.2;

      // Orbit movement
      particle.y += particle.speed * (1 + clampedStress * 5);
      if (particle.y > 5) particle.y = -5; // wrap around

      dummy.position.set(
        particle.initialX + jitterX,
        particle.y + jitterY,
        particle.initialZ
      );
      dummy.scale.setScalar(targetScale);
      dummy.updateMatrix();
      meshRef.current!.setMatrixAt(i, dummy.matrix);
    });

    meshRef.current.instanceMatrix.needsUpdate = true;
  });

  return (
    <instancedMesh ref={meshRef} args={[undefined, undefined, count]}>
      <sphereGeometry args={[0.5, 8, 8]} />
      <meshBasicMaterial color="#ef4444" transparent opacity={0.6} />
    </instancedMesh>
  );
}
