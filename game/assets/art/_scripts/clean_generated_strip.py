#!/usr/bin/env python3
"""Remove a baked light checkerboard while preserving outlined white details.

The generated concept sheets use a nearly-white checkerboard as pixels rather
than real transparency. A global color key would also erase the knight's armor
and the wizard's beard, so this script only removes light neutral pixels that
are connected to the canvas edge. A second edge-growth pass clears the soft
neutral fringe without crossing the sprites' dark outlines.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def _neutral_light(rgb: np.ndarray, minimum: int, spread: int) -> np.ndarray:
	lo = rgb.min(axis=2)
	hi = rgb.max(axis=2)
	return (lo >= minimum) & ((hi - lo) <= spread)


def _edge_connected(mask: np.ndarray) -> np.ndarray:
	height, width = mask.shape
	seen = np.zeros_like(mask, dtype=bool)
	queue: deque[int] = deque()

	def seed(y: int, x: int) -> None:
		if mask[y, x] and not seen[y, x]:
			seen[y, x] = True
			queue.append(y * width + x)

	for x in range(width):
		seed(0, x)
		seed(height - 1, x)
	for y in range(height):
		seed(y, 0)
		seed(y, width - 1)

	while queue:
		index = queue.popleft()
		y, x = divmod(index, width)
		if x > 0:
			seed(y, x - 1)
		if x + 1 < width:
			seed(y, x + 1)
		if y > 0:
			seed(y - 1, x)
		if y + 1 < height:
			seed(y + 1, x)
	return seen


def _grow_fringe(background: np.ndarray, fringe: np.ndarray, passes: int) -> np.ndarray:
	for _ in range(passes):
		adjacent = np.zeros_like(background)
		adjacent[1:] |= background[:-1]
		adjacent[:-1] |= background[1:]
		adjacent[:, 1:] |= background[:, :-1]
		adjacent[:, :-1] |= background[:, 1:]
		added = fringe & adjacent & ~background
		if not added.any():
			break
		background |= added
	return background


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--input", required=True)
	parser.add_argument("--output", required=True)
	parser.add_argument("--fringe-passes", type=int, default=8)
	args = parser.parse_args()

	image = Image.open(args.input).convert("RGBA")
	pixels = np.asarray(image).copy()
	rgb = pixels[:, :, :3]
	background = _edge_connected(_neutral_light(rgb, minimum=236, spread=14))
	background = _grow_fringe(
		background,
		_neutral_light(rgb, minimum=214, spread=22),
		args.fringe_passes,
	)
	pixels[:, :, 3] = np.where(background, 0, 255).astype(np.uint8)

	output = Path(args.output)
	output.parent.mkdir(parents=True, exist_ok=True)
	Image.fromarray(pixels, "RGBA").save(output)


if __name__ == "__main__":
	main()
