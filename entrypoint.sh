#!/bin/bash
set -e

# 1. قراءة المدخلات الأساسية
TARGET_BRANCH="${INPUT_BRANCH}"
TEAM_LEADERS="${INPUT_TEAM_LEADERS}"
DEVOPS_USERS="${INPUT_DEVOPS}"
DEVELOPERS_LIST="${INPUT_DEVELOPERS}"
GH_PAT="${INPUT_PAT}"
ACTOR="${GITHUB_ACTOR}"

echo "======================================================"
echo "Checking CodeWall Protection for User: $ACTOR"
echo "Target Branch: $TARGET_BRANCH"
echo "======================================================"

USER_ROLE="unauthorized"

# 2. تحديد دور المستخدم بناءً على القوائم
if [[ " ,${TEAM_LEADERS}, " == *",${ACTOR},"* ]]; then
    USER_ROLE="team_leader"
elif [[ " ,${DEVOPS_USERS}, " == *",${ACTOR},"* ]]; then
    USER_ROLE="devops"
elif [[ " ,${DEVELOPERS_LIST}, " == *",${ACTOR},"* ]]; then
    USER_ROLE="developer"
fi

echo "Identified Role for $ACTOR: $USER_ROLE"

AUTHORIZED="false"

# 3. فحص الصلاحيات
if [[ "$USER_ROLE" == "team_leader" || "$USER_ROLE" == "devops" ]]; then
    echo "Access granted: $USER_ROLE has bypass permissions to all branches."
    AUTHORIZED="true"
elif [[ "$USER_ROLE" == "developer" ]]; then
    if [[ "$TARGET_BRANCH" == "main" || "$TARGET_BRANCH" == "master" || "$TARGET_BRANCH" == "production" ]]; then
        echo "Access denied: Developers cannot push directly to $TARGET_BRANCH. Please use Pull Requests."
        AUTHORIZED="false"
    else
        echo "Access granted: Developers are permitted to push to $TARGET_BRANCH."
        AUTHORIZED="true"
    fi
else
    echo "CRITICAL ACCESS DENIED: User $ACTOR is not registered in any role! Strict protection triggered."
    AUTHORIZED="false"
fi

# 4. تفعيل آلية الـ Revert والتراجع الإجباري
if [[ "$AUTHORIZED" == "false" && "$ACTOR" != "github-actions[bot]" ]]; then
    echo "------------------------------------------------------"
    echo "Starting automated revert process for $ACTOR..."
    echo "------------------------------------------------------"
    
    # تهيئة إعدادات Git داخل الـ Runner لتفادي مشاكل المجلدات الآمنة
    git config --global user.name "github-actions[bot]"
    git config --global user.email "github-actions[bot]@users.noreply.github.com"
    git config --global --add safe.directory /github/workspace
    git config --global --add safe.directory "$GITHUB_WORKSPACE"

    echo "Executing local hard reset to HEAD~1..."
    git reset --hard HEAD~1
    
    echo "Setting up secure remote origin with GH_PAT..."
    
    # [تعديل جوهري]: جلب الرابط الحالي للمشروع من Git مباشرة وتعديله بالتوكن بدلاً من كتابة المتغيرات يدوياً
    ORIGINAL_URL=$(git remote get-url origin)
    # تحويل الرابط من الصيغة العادية إلى صيغة تحتوى على الـ PAT token الخاص بك
    SECURE_URL=$(echo "$ORIGINAL_URL" | sed -E "s|https://[^@]+@|https://|g" | sed -E "s|https://|https://x-access-token:${GH_PAT}@|g")
    
    git remote set-url origin "$SECURE_URL"
    
    echo "Pushing the hard reset back to origin branch: $TARGET_BRANCH..."
    git push origin "$TARGET_BRANCH" --force
    
    echo "======================================================"
    echo "SUCCESS: Unauthorized changes completely wiped from $TARGET_BRANCH!"
    echo "======================================================"
    
    exit 1
fi

echo "======================================================"
echo "Verification complete. Proceeding with workflow safely."
echo "======================================================"
