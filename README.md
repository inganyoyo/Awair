# Awair
## About
Awair QuickApp for Fibaro HC3

### Installation
    1. HC3 > Settings > 5. Devices > Add Device > Other Device를 선택
    2. Quick App 클릭 > 장치의 Name 및 Room 선택 > Device Type "Bibary switch" 선택 후 저장
    3. 생성된 장치로 선택 후 Edit & Preview 탭으로 이동하여 Edit 화면으로 이동
    4. Awair.lua의 내용을 Edit 화면에 넣은 후 저장
    5. Variables 탭으로 이동하여 변수를 넣고 저장한다.
    
```yaml
AWAIR_IP                    -- Awair Device IP
AWAIR_INTERVAL              -- Awair 데이터를 조회하는 간격 (초)
```

**# 부모 Device Show in History 값에 따라 하위 Device 또한 저장 여부를 결정**