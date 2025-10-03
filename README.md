# Storage Device Management (Assembly) — README

## Short description

This project implements a simplified storage device management module (hard disk / SSD) intended as part of a minimal operating system. It simulates allocation and management of files on a storage device using two memory models:

* **One-dimensional (1D)** — memory modeled as a single vector (array) of blocks.
* **Two-dimensional (2D)** — memory modeled as a matrix of blocks; contiguous sections are considered along rows.

The module supports the basic operations: **ADD**, **GET**, **DELETE**, and **DEFRAGMENTATION**, following the constraints and conventions described in the assignment.

---

## Key constraints and conventions

* **Total capacity (theoretical):** 8 MB (as specified in the assignment). For demonstration and testing the implementation uses reduced sizes (example: representing an 8KB block as 8 bytes) — follow the conversion rules from the assignment.
* **Block size:** 8 kB (assignment). For simplified testing the example representation uses 8 B per block.
* **File descriptor:** integer in range `1..255`. The value `0` in a block denotes a free block.
* **Allocation rules:** a file must be stored **contiguously** and needs at least **2 blocks**.
* **Units:** 1 MB = 1024 kB; 1 kB = 1024 B.

---

## Supported operations (both 1D and 2D)

* **ADD** — allocate the first free contiguous interval (scan left-to-right, line-by-line for 2D). If allocation succeeds print the allocated interval; otherwise print the failure interval (all zeros) in the required format.
* **GET** — return the interval where a given descriptor is stored, or an all-zero interval if the file is not present.
* **DELETE** — free all blocks belonging to a descriptor (set their values to `0`) and print the updated memory when required by the assignment.
* **DEFRAGMENTATION** — rearrange allocated blocks to make storage compact while preserving file order: in 1D move data left; in 2D compact by rows so free blocks (zeros) end up at bottom-right.

Additional operation in 2D:

* **CONCRETE (code 5)** — scan a given folder, for each file compute a descriptor `(fd_real % 255) + 1`, compute file size in kB, and treat the pair as an ADD input. If the computed descriptor collides with an already-used descriptor, print the failure interval but do not add the file.

---

## Input format

The program reads from `stdin`.

1. First line: number of operations `O`.
2. For each operation, read a line with its **operation code**:

   * `1` — ADD
   * `2` — GET
   * `3` — DELETE
   * `4` — DEFRAGMENTATION
   * `5` — CONCRETE (2D only)

### If operation is `ADD`:

* Next line: integer `N` — number of files to add.
* Next `2*N` lines: for each file two lines: `descriptor` and `size_in_kB`.

### If operation is `GET` or `DELETE`:

* Next line: `descriptor`.

### If operation is `CONCRETE` (2D only):

* Next line: absolute path to a folder containing files to be processed.

---

## Output format (exact strings expected)

Follow the assignment format precisely when printing results.

### 1D formats

* **ADD success:** `%d: (%d, %d)
  `  — `descriptor: (start_block, end_block)` (closed interval)
* **ADD failure:** `fd: (0, 0)
  `  — where `fd` is the descriptor that failed to insert
* **GET:** `(%d, %d)
  ` — start and end or `(0, 0)` if not present
* **DELETE / DEFRAGMENTATION:** print the memory vector state if the assignment requires it (see spec examples)

### 2D formats

* **ADD success:** `%d: ((%d, %d), (%d, %d))
  ` — `descriptor: ((startRow, startCol), (endRow, endCol))`
* **ADD failure:** `fd: ((0, 0), (0, 0))
  `
* **GET:** `((%d, %d), (%d, %d))
  `
* **DELETE / DEFRAGMENTATION:** print the matrix state as described in the assignment examples

---

## Behavior examples (high-level)

* When adding multiple files in one ADD operation, print the allocation result for each file in the order they were given.
* For GET, if the descriptor does not exist return the all-zero interval.
* For DELETE, if the descriptor does not exist, the memory remains unchanged.
* DEFRAGMENTATION must preserve the relative order of files and produce a compact layout.

---

## Running / Testing locally

To avoid typing long inputs interactively create test files and redirect them to `stdin`.

```bash
# Example: run the 1D task executable
./task00 < input1.txt

# Example: run the 2D task executable
./task01 < input2.txt
```

Create multiple input files (e.g. `input0.txt`, `input1.txt`) to exercise different scenarios.

---

## Recommended project layout

```
/ (root)
├─ src/                # assembly or C helper sources
├─ build/              # compiled binaries
├─ tests/              # test input files and expected outputs
├─ README.md
└─ Makefile / build.sh  # optional build scripts
```

---

## Implementation notes & suggestions

* For **ADD (1D)**: implement a linear scan for the first contiguous free interval of the required length.

* For **GET (1D)**: either scan for the descriptor or maintain a descriptor → interval map (but remember to keep it consistent on DELETE and DEFRAGMENTATION).

* For **DELETE (1D)**: set matching blocks to `0` and update any auxiliary structures.

* For **DEFRAGMENTATION (1D)**: compact non-zero blocks to the left, updating intervals reported by GET/ADD.

* For **ADD (2D)**: search each row for a contiguous sequence of free blocks long enough for the file; return the first suitable interval.

* For **DEFRAGMENTATION (2D)**: flatten row-major, move used blocks up-left preserving order, leaving zeros at bottom-right.

---


## Limitations

* Storage allocation requires contiguous space; the implementation does not support non-contiguous (chained) storage.
* The CONCRETE operation depends on the host filesystem APIs for file size and descriptor (open). Behaviour may differ across platforms.

---

## Possible extensions

* Maintain an index (map) for descriptor → interval to accelerate GET.
* Implement alternative allocation strategies: `best-fit`, `worst-fit`.
* Support non-contiguous file storage and metadata structures (file table, directory simulation).

---

## Author

Balaceanu Rafael Gabriel

---

