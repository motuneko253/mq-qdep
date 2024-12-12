#!/bin/bash

# 引数チェック
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <queue_manager_name>"
    exit 1
fi

queue_manager=$1
tmp_file="/tmp/qdep_tmp.txt"

# キューマネージャが存在するか、実行中か確認
mq_status=$(dspmq -m "${queue_manager}" 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "Error: Queue manager '${queue_manager}' does not exist."
    exit 1
fi

if ! echo "${mq_status}" | grep -q "実行中"; then
    echo "Error: Queue manager '${queue_manager}' is not running."
    exit 1
fi

# MQSC コマンドを実行し、一時ファイルに出力
echo "dis ql(*) curdepth" | runmqsc "${queue_manager}" | \
    sed 's/^[^  ].*$/%/g' | tr -s " " | tr -d "\n" | tr "%" "\n" | \
    egrep -v "^ QUEUE\(SYSTEM" | sort > "${tmp_file}"

# 実行結果を確認
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute runmqsc command on queue manager '${queue_manager}'."
    rm -f "${tmp_file}"
    exit 2
fi

# ヘッダー表示
printf "    %-30s：%-4s\n" "queue name" "message count"

# 一時ファイルからキュー情報を読み取り、表示
while read -r line; do
    if [[ "${line}" =~ ^\ *QUEUE ]]; then
        # QUEUE と CURDEPTH の部分を抽出し、表示
        queue=$(echo "${line}" | grep -oP 'QUEUE\(\K[^)]+')
        curdepth=$(echo "${line}" | grep -oP 'CURDEPTH\(\K[^)]+')
        printf "    %-30s：%-4s\n" "${queue}" "${curdepth}"
    fi
done < "${tmp_file}"

# 一時ファイルの削除
rm -f "${tmp_file}"
exit 0
