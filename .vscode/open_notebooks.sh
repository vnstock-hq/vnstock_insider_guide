#!/bin/bash

# Script để mở tất cả các notebook trong thư mục demo
# Sử dụng: bash .vscode/open_notebooks.sh

DEMO_DIR="demo"

# Mở tất cả các .ipynb files trong thư mục demo
for notebook in $(find "$DEMO_DIR" -name "*.ipynb" -type f | sort); do
    echo "Mở: $notebook"
    code --open-file "$notebook"
done

echo "✓ Đã mở tất cả các notebook"
