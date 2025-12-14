#!/bin/bash

# Mở tất cả các notebook trong thư mục demo
echo "Opening notebooks..."

# Chờ VS Code sẵn sàng
sleep 3

# Mở các notebook một cách tuần tự
code demo/1-vnstock_data_explorer_v2_demo.ipynb
sleep 1
code demo/2-vnstock_ta-demo.ipynb
sleep 1
code demo/3-vnstock_pipeline_v2_demo.ipynb
sleep 1
code demo/4-vnstock_news_v2.1_demo.ipynb

echo "Notebooks opened successfully!"
