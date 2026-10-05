import sys
import cv2
import numpy as np

frame_path, screen_path, out_path = sys.argv[1:4]
frame = cv2.imread(frame_path)
screen = cv2.imread(screen_path)
hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
mask = cv2.inRange(hsv, (40, 120, 90), (85, 255, 255))
mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contour = max(contours, key=cv2.contourArea)
hull = cv2.convexHull(contour)
quad = cv2.approxPolyDP(hull, 0.02 * cv2.arcLength(hull, True), True).reshape(-1, 2).astype(np.float32)
if len(quad) != 4:
    rect = cv2.minAreaRect(contour)
    quad = cv2.boxPoints(rect).astype(np.float32)
s = quad.sum(axis=1); d = np.diff(quad, axis=1).ravel()
ordered = np.array([quad[np.argmin(s)], quad[np.argmin(d)], quad[np.argmax(s)], quad[np.argmax(d)]], dtype=np.float32)
h, w = screen.shape[:2]
src = np.array([[0, 0], [w, 0], [w, h], [0, h]], dtype=np.float32)
M = cv2.getPerspectiveTransform(src, ordered)
warped = cv2.warpPerspective(screen, M, (frame.shape[1], frame.shape[0]), flags=cv2.INTER_LANCZOS4)
area = np.zeros(frame.shape[:2], np.uint8)
cv2.fillConvexPoly(area, ordered.astype(np.int32), 255)
area = cv2.dilate(area, np.ones((3, 3), np.uint8))
soft = cv2.GaussianBlur(area, (3, 3), 0).astype(np.float32)[..., None] / 255
near = cv2.dilate(area, np.ones((25, 25), np.uint8))
green = cv2.dilate(cv2.bitwise_and(mask, near), np.ones((5, 5), np.uint8)).astype(np.float32)[..., None] / 255
alpha = np.maximum(soft, green)
out = (warped * alpha + frame * (1 - alpha)).astype(np.uint8)
cv2.imwrite(out_path, out)
print(out_path, ordered.tolist(), int(cv2.contourArea(contour)))
