#define GLEW_DYNAMIC
#include <GL/glew.h>
#include "Common.h"
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include "Camera.hpp"
#include "ParticleSystem.cpp"
#include "Renderer.h"
#include "Renderer.cpp"
#include "Scene.hpp"
#include <cuda_profiler_api.h>
#include <cuda_gl_interop.h>
#include <stdlib.h>
#include <string>
#include <iostream>

using namespace std;

static const int width = 1280;
static const int height = 720;

static float deltaTime = 0.0f;
static float lastFrame = 0.0f;
static int frameCounter = -1;
static bool paused = true;
static bool spacePressed = false;

void handleInput(GLFWwindow* window, ParticleSystem &system, Camera &cam);
void mainUpdate(ParticleSystem& system, Renderer& renderer, Camera& cam, solverParams& params);

template <typename T> string tostr(const T& t) {
   ostringstream os;
   os<<t;
   return os.str();
}

int main() {

	cudaGLSetGLDevice(0);

	if (!glfwInit()) exit(EXIT_FAILURE);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	GLFWwindow* window = glfwCreateWindow(width, height, "A Material Point Method for Snow Simulation", NULL, NULL);
	if (!window) {
		glfwTerminate();
		exit(EXIT_FAILURE);
	}

	glfwMakeContextCurrent(window);

	//Set callbacks for keyboard and mouse
	glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);

	glewExperimental = GL_TRUE;
	glewInit();
	glGetError();

	//Define the viewport dimensions
	glViewport(0, 0, width, height);

	//Create scenes
	vector<Particle> particles;

	WallSmash scene("Wallsmash");
	solverParams sp;

	scene.init(particles, &sp);

	Camera cam = Camera();
	cam.eye = glm::vec3(sp.boxCorner2.x, sp.boxCorner2.y, sp.boxCorner2.z);
	Renderer renderer = Renderer(width, height, &sp);
	renderer.setProjection(glm::infinitePerspective(cam.zoom, float(width) / float(height), 0.1f));

	ParticleSystem system = ParticleSystem(particles, sp);

	//Initialize buffers for drawing snow
	renderer.initSnowBuffers(sp.numParticles);

	//Take 1 step for initialization
	system.updateWrapper(sp);

	while (!glfwWindowShouldClose(window)) {
		//Set frame times

		float currentFrame = float(glfwGetTime());
		deltaTime = currentFrame - lastFrame;
		lastFrame = currentFrame;
		//Check and call events
		glfwPollEvents();
		handleInput(window, system, cam);

		//Step physics and render
		mainUpdate(system, renderer, cam, sp);

		//Swap the buffers
		glfwSwapBuffers(window);

		//Save video if turned on

		if (!paused) {
			if (frameCounter % (int)(1 / (sp.deltaT * 30 * 3)) == 0) {
				cout << lastFrame << endl;

			}
		}
	}

	glfwTerminate();

	return 0;
}

void handleInput(GLFWwindow* window, ParticleSystem &system, Camera &cam) {
	if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
		glfwSetWindowShouldClose(window, GL_TRUE);

	if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
		cam.wasdMovement(FORWARD, deltaTime);

	if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
		cam.wasdMovement(BACKWARD, deltaTime);

	if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
		cam.wasdMovement(RIGHT, deltaTime);

	if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
		cam.wasdMovement(LEFT, deltaTime);

	if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS)
		cam.wasdMovement(UP, deltaTime);

	if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS)
		cam.wasdMovement(DOWN, deltaTime);

	if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS)
		spacePressed = true;

	if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_RELEASE) {
		if (spacePressed) {
			spacePressed = false;
			if (paused) {
				cout << "Running Simulation..." << endl;
			} else {
				cout << "Pausing Simulation..." << endl;
			}
			paused = !paused;
		}
	}

}

void mainUpdate(ParticleSystem& system, Renderer& renderer, Camera& cam, solverParams& params) {
	//Step physics
	if (!paused) {
		system.updateWrapper(params);
		frameCounter++;
	}

	//Update the VBO
	void* positionsPtr;
	cudaCheck(cudaGraphicsMapResources(1, &renderer.resource));
	size_t size;
	cudaGraphicsResourceGetMappedPointer(&positionsPtr, &size, renderer.resource);
	system.getPositionsWrapper((float*)positionsPtr);
	cudaGraphicsUnmapResources(1, &renderer.resource, 0);

	//Render
	renderer.render(cam);
}
