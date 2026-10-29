# Music Lyrics Bar

Apple Music이 표시하는 **원본 가사**를 재생 위치에 맞춰 macOS 메뉴바에 보여 주는 네이티브 앱입니다.

**상태: 초기 구현 / 실험적 캐시 연동.** 외부 가사 검색 서비스는 사용하지 않습니다. Music이 이미 내려받은 로컬 TTML 가사와 타이밍을 읽습니다. Apple의 비공개 캐시 형식에 의존하므로 macOS 또는 Music 업데이트로 동작이 달라질 수 있습니다.

## 시작하기

macOS 13 이상, Swift 6 이상이 포함된 Xcode 또는 Command Line Tools가 필요합니다.

```sh
git clone https://github.com/mytrashcan/applemusic-menubar-lyrics.git
cd applemusic-menubar-lyrics
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Music Lyrics Bar.app"
```

1. 메뉴바의 **Music 연결**을 누르고 메뉴에서 **Music 연결…**을 선택합니다.
2. macOS가 Music 자동화 권한을 요청하면 허용합니다. 앱은 현재 곡과 재생 위치를 읽습니다.
3. Music에서 곡을 재생하고 **가사 패널을 한 번 엽니다.** Music이 이 곡의 가사를 캐시에 저장해야 합니다.
4. 캐시가 준비되면 앱이 자동으로 다시 읽습니다. 메뉴의 **가사 캐시 다시 읽기**로 재시도할 수도 있습니다.

빌드 결과는 `dist/Music Lyrics Bar.app`과 `dist/MusicLyricsBar.zip`입니다. 로컬 사용을 위한 ad-hoc 서명이며 Developer ID 서명 또는 공증된 배포본은 아닙니다. 테스트와 패키징은 GitHub Actions에서도 실행합니다.

## 구현한 동작

- 메뉴바에 현재 줄 표시, 긴 줄 말줄임, 전체 줄 툴팁과 주변 가사 메뉴
- 0.5초 간격으로 Music 재생 정보 조회, 조회 사이에는 단조 시계로 위치 보간
- 일시정지 시 보간 중지, 탐색 및 곡 변경 반영
- 가사 사이의 간주 구간에는 곡 제목 표시, 동시에 부르는 줄은 함께 표시
- 제목·아티스트·앨범·재생 시간을 비교해 다른 녹음 버전의 가사 혼입 방지
- 캐시가 없거나 권한이 거부된 상태 안내, 실패한 캐시 조회는 3초 간격으로 재시도

## 데이터 흐름과 개인정보

```text
Music.app ── Apple Events ── 현재 곡 / 재생 위치
                                   │
Music의 로컬 캐시 ── 읽기 전용 ── 곡 매칭 → TTML 파싱
                                   │
                               메뉴바 표시
```

캐시 조회 대상:

```text
~/Library/Caches/com.apple.Music/Cache.db
~/Library/Caches/com.apple.Music/fsCachedData/
```

앱 자체는 네트워크 요청을 하지 않습니다. 캐시 DB를 읽기 전용으로 열며 계정 토큰, 요청 헤더, 보관함 DB를 읽지 않습니다. 가사나 감상 이력을 별도 파일로 저장하거나 전송하지 않습니다. 접근성 권한과 화면 녹화 권한은 사용하지 않습니다.

`LyricsCore`는 가사 모델, Apple TTML 파서, 재생 시계와 SQLite 캐시 조회를 담당합니다. `MusicLyricsBar`는 직렬 actor에서 Apple Events 및 캐시 조회를 수행하고, 메인 스레드에서 AppKit 메뉴바 UI를 갱신합니다. 외부 패키지 의존성은 없습니다.

## 검증

```sh
# 합성 가사와 임시 SQLite DB를 사용하는 결정적 단위 테스트
bash scripts/test.sh

# 선택: 이 Mac의 실제 Music 캐시도 읽어서 파싱·매칭 검증
MUSIC_LYRICS_CACHE_INTEGRATION=1 bash scripts/test.sh
```

테스트는 시간 형식, 단어 span과 줄바꿈, 메타데이터 제외, 잘못된 XML, 줄 경계와 간주 구간, 겹치는 가사, 일시정지와 역방향 탐색, 캐시 미스 후 재시도, 잘못된 곡 매칭, 캐시의 읽기 전용 접근 및 파일 경로 검증을 다룹니다. Music 연동 스크립트는 실행 없이 사전 컴파일하여 문법도 검증합니다. 저장소의 테스트 데이터는 합성 텍스트만 포함합니다. 선택적 로컬 통합 테스트는 가사나 곡 제목을 출력하지 않습니다.

실제 캐시 파싱과 패키징 통과만으로 Music 자동화 권한 승인 이후의 전체 동작이 검증되지는 않습니다. 수동 확인 항목은 다음과 같습니다.

- Music 재생 중 메뉴바 줄과 Music의 가사 줄 비교
- 일시정지, 앞뒤 탐색 및 곡 변경
- 가사를 캐시에 저장한 뒤 Music 창을 뒤로 보내거나 최소화
- 자동화 권한 거부 후 다시 연결

## 현재 한계

- Music이 내려받지 않은 가사는 가져올 수 없습니다. 앱이 직접 가사 API에 요청하지 않습니다.
- 최근 가사 관련 캐시 응답 최대 512개를 조회합니다. 오래된 캐시만 남아 있으면 Music에서 가사를 다시 열어 주세요.
- 곡 메타데이터가 캐시와 다르거나 별도 형식으로 저장되면 매칭에 실패할 수 있습니다. 추측한 다른 곡의 가사를 대신 표시하지 않습니다.
- 현재는 줄 단위 원문 표시입니다. 번역·발음·단어별 노래방 하이라이트는 구현하지 않았습니다.
- 첫 실행마다 연결 메뉴를 사용합니다. 자동 실행·설정 저장·공증된 설치본은 아직 제공하지 않습니다.
- Music 캐시 형식은 공개 API가 아닙니다. App Store 배포 가능 여부는 검증하지 않았습니다.

## 참고

로컬 캐시 접근의 선행 사례: [apple-music-lyrics](https://github.com/Takpap/apple-music-lyrics), [applyrx](https://github.com/rakei076/applyrx). 이 프로젝트는 로컬에서 확인한 캐시 구조를 바탕으로 구현했습니다.

Apple과 무관한 비공식 프로젝트입니다. 가사와 관련 콘텐츠의 권리는 각 권리자에게 있습니다.
