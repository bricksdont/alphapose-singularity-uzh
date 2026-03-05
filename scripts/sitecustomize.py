# Compatibility shim for packages using removed NumPy type aliases.
# numpy>=1.24 removed np.float, np.int, np.complex, np.bool, np.object.
# cython_bbox (used by AlphaPose) still references np.float at import time.
import numpy
numpy.float = float
numpy.int = int
numpy.complex = complex
numpy.bool = bool
numpy.object = object
