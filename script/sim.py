import os
from pathlib import Path
from hdlregression import HDLRegression

ROOT = Path(__file__).resolve().parents[1]

DEFAULT_UVVM = Path.home() / "dev" / "UVVM" / "GITHUB_UVVM"
UVVM = Path(os.environ.get("UVVM_ROOT", DEFAULT_UVVM)).expanduser().resolve()
if not (UVVM / "uvvm_util" / "script" / "compile_order.txt").is_file():
    raise SystemExit(
        f"UVVM ble ikke funnet i {UVVM}. "
        "Sett UVVM_ROOT til rotmappen for din UVVM-installasjon."
    )

hr = HDLRegression()

for lib in (
    "uvvm_util",
    "uvvm_vvc_framework",
    "bitvis_vip_scoreboard",
    "bitvis_vip_sbi",
    "bitvis_vip_clock_generator",
):
    order = UVVM / lib / "script" / "compile_order.txt"
    for line in order.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            hr.add_files(str((order.parent / line).resolve()), library_name=lib)

hr.add_files(str(ROOT / "src/mem_block.vhd"), library_name="design_lib")

for file in ("mem_block_tb_pkg.vhd", "mem_block_th.vhd", "mem_block_tb.vhd"):
    hr.add_files(str(ROOT / "tb" / file), library_name="test_lib")

for seed in os.environ.get("MEM_SEEDS", "17").split(","):
    hr.add_generics(
        entity="mem_block_tb",
        architecture="tb",
        generics=[
            "GC_SEED",           int(seed),
            "GC_ADDR_WIDTH",     int(os.environ.get("MEM_ADDR_WIDTH", "12")),
            "GC_DATA_WIDTH",     int(os.environ.get("MEM_DATA_WIDTH", "32")),
            "GC_ITERATIONS",     int(os.environ.get("MEM_ITERATIONS", "512")),
            "GC_MAX_ITERATIONS", int(os.environ.get("MEM_MAX_ITERATIONS", "1000")),
            "GC_DEMO_ALIAS_BUG", os.environ.get("MEM_DEMO_BUG", "false"),
        ],
    )

raise SystemExit(hr.start())
