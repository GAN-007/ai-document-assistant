import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { DocumentContext } from '../context/DocumentContext';

/**
 * ThreeDAnimation component for rendering a 3D spinning cube with dynamic colors.
 */
const ThreeDAnimation = () => {
    const { colorGradient } = React.useContext(DocumentContext);
    const mountRef = useRef(null);

    useEffect(() => {
        // Scene setup
        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(75, 1, 0.1, 1000);
        const renderer = new THREE.WebGLRenderer({ alpha: true });
        renderer.setSize(200, 200);
        mountRef.current.appendChild(renderer.domElement);

        // Cube geometry and material
        const geometry = new THREE.BoxGeometry();
        const material = new THREE.MeshBasicMaterial({
            color: colorGradient.start,
            wireframe: true,
        });
        const cube = new THREE.Mesh(geometry, material);
        scene.add(cube);

        // Position camera
        camera.position.z = 5;

        // Animation loop
        const animate = () => {
            requestAnimationFrame(animate);
            cube.rotation.x += 0.01;
            cube.rotation.y += 0.01;
            renderer.render(scene, camera);
        };
        animate();

        // Cleanup
        return () => {
            mountRef.current.removeChild(renderer.domElement);
            renderer.dispose();
        };
    }, [colorGradient.start]);

    return (
        <div
            className="scene mx-auto"
            ref={mountRef}
            data-testid="three-d-animation"
            aria-hidden="true"
        />
    );
};

export default ThreeDAnimation;