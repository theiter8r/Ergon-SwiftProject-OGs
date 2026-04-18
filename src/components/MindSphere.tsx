"use client";
import { useRef } from "react";
import { useFrame } from "@react-three/fiber";
import { MeshDistortMaterial, Sphere } from "@react-three/drei";
import * as THREE from "three";
import { useScroll } from "framer-motion";

export function MindSphere({ isCalm }: { isCalm: boolean }) {
  const meshRef = useRef<THREE.Mesh>(null);
  const materialRef = useRef<any>(null);
  
  // Use Framer Motion's useScroll to get scroll position
  const { scrollYProgress } = useScroll();

  useFrame((state, delta) => {
    if (!meshRef.current || !materialRef.current) return;

    // Base rotation
    meshRef.current.rotation.y += delta * 0.1;

    // Handle mouse interaction
    const targetX = state.pointer.x * 0.2;
    const targetY = state.pointer.y * 0.2;
    
    meshRef.current.rotation.x += (targetY - meshRef.current.rotation.x) * delta * 2;
    meshRef.current.rotation.y += (targetX - meshRef.current.rotation.y) * delta * 2;

    // Calculate stress based on scroll (0 to 1)
    const scrollStress = isCalm ? 0 : scrollYProgress.get() * 1.5; // Multiply for faster onset
    const clampedStress = Math.min(Math.max(scrollStress, 0), 1);
    
    // Animate material properties
    const targetDistort = 0.2 + clampedStress * 0.7; // From 0.2 to 0.9
    const targetSpeed = 1 + clampedStress * 6;       // From 1 to 7
    
    materialRef.current.distort = THREE.MathUtils.lerp(materialRef.current.distort, targetDistort, delta * 3);
    materialRef.current.speed = THREE.MathUtils.lerp(materialRef.current.speed, targetSpeed, delta * 3);
    
    // Color shift: Calm (blue) to Stressed (orange/red)
    const calmColor = new THREE.Color("#60a5fa"); // Lighter Blue
    const stressedColor = new THREE.Color("#fb923c"); // Lighter Orange
    const targetColor = calmColor.clone().lerp(stressedColor, clampedStress);
    
    materialRef.current.color.copy(targetColor);
    materialRef.current.emissive.copy(targetColor);

    // Flickering emissive intensity when stressed
    let targetEmissiveIntensity = 0.6;
    if (clampedStress > 0.3) {
       // Random flickering
        const flicker = Math.random() > 0.8 ? 0.3 + Math.random() * 0.4 : 0;
        targetEmissiveIntensity = 0.6 + clampedStress * flicker;
    }
    
    // Wait, MeshDistortMaterial emissiveIntensity is supported in standard material but maybe not directly exposed? 
    // It inherits from standard material so yes it is.
    // Actually Drei's MeshDistortMaterial is a CustomMaterial, it usually passes standard props down.
    // To safely animate it, we might need to rely on the material object.
    if (materialRef.current.emissiveIntensity !== undefined) {
      // Lerp intensity slowly unless it's flickering
      materialRef.current.emissiveIntensity = THREE.MathUtils.lerp(
        materialRef.current.emissiveIntensity, 
        targetEmissiveIntensity, 
        delta * 10
      );
    }
  });

  return (
    <Sphere ref={meshRef} args={[1.15, 64, 64]}>
      <MeshDistortMaterial
        ref={materialRef}
        color="#60a5fa"
        emissive="#60a5fa"
        emissiveIntensity={0.6}
        roughness={0.2}
        metalness={0.5}
        transparent={true}
        opacity={0.2} /* highly transparent */
        distort={0.2}
        speed={1}
      />
    </Sphere>
  );
}
