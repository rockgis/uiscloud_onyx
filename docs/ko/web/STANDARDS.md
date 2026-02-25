# 웹 코딩 표준

이 문서는 `web` 디렉토리 Next.js 프로젝트의 코딩 표준 및 Best Practice를 설명합니다.

---

## 1. Import 표준

**항상 `@` 접두사를 사용하는 절대 import를 사용하세요.**

**이유:** 파일을 이동할 때 import 문을 업데이트할 필요가 없어 코드베이스 수정이 훨씬 편리합니다.

```typescript
// ✅ 올바른 방법
import { Button } from "@/components/ui/button";
import { useAuth } from "@/hooks/useAuth";
import { Text } from "@/refresh-components/texts/Text";

// ❌ 잘못된 방법
import { Button } from "../../../components/ui/button";
import { useAuth } from "./hooks/useAuth";
```

---

## 2. React 컴포넌트 함수

**React 컴포넌트에는 화살표 함수보다 일반 함수를 선호하세요.**

**이유:** 일반 함수가 더 읽기 쉽습니다.

```typescript
// ✅ 올바른 방법
function UserProfile({ userId }: UserProfileProps) {
  return <div>사용자 프로필</div>
}

// ❌ 잘못된 방법
const UserProfile = ({ userId }: UserProfileProps) => {
  return <div>사용자 프로필</div>
}
```

---

## 3. Props 인터페이스 추출

**Props 타입은 별도의 인터페이스 정의로 추출하세요.**

**이유:** 함수가 더 읽기 쉬워집니다.

```typescript
// ✅ 올바른 방법
interface UserCardProps {
  user: User
  showActions?: boolean
  onEdit?: (userId: string) => void
}

function UserCard({ user, showActions = false, onEdit }: UserCardProps) {
  return <div>사용자 카드</div>
}

// ❌ 잘못된 방법
function UserCard({
  user,
  showActions = false,
  onEdit
}: {
  user: User
  showActions?: boolean
  onEdit?: (userId: string) => void
}) {
  return <div>사용자 카드</div>
}
```

---

## 4. 간격(Spacing) 가이드라인

**간격에는 margin보다 padding을 선호하세요.**

**이유:** padding 사용을 통일하기 위함입니다.

```typescript
// ✅ 올바른 방법
<div className="p-4 space-y-2">
  <div className="p-2">콘텐츠</div>
</div>

// ❌ 잘못된 방법
<div className="m-4 space-y-2">
  <div className="m-2">콘텐츠</div>
</div>
```

---

## 5. Tailwind 다크 모드

**로고 아이콘 처리를 제외하고 Tailwind 클래스에서 `dark:` 수정자 사용을 엄격히 금지합니다.**

**이유:** `colors.css` 파일이 이미 각 라이트 모드 색상의 정확한 반대 색상을 매우 신중하게 정의합니다. 이 동작을 재정의하면 UI가 크게 깨질 수 있습니다.

**예외:** `web/src/components/icons/icons.tsx`의 `createLogoIcon` 헬퍼는 `colors.css`를 통해 자동으로 적응할 수 없는 서드파티 로고 아이콘을 처리하기 위해 `dark:invert`, `dark:hidden`, `dark:block`을 사용합니다. 이것이 다크 모드 수정자의 **유일하게 허용되는** 사용법입니다.

```typescript
// ✅ 올바른 방법 - 표준 컴포넌트는 colors.css 사용
<div className="bg-background-neutral-03 text-text-02">
  콘텐츠
</div>

// ✅ 올바른 방법 - createLogoIcon을 통한 로고 아이콘 다크 모드 처리
export const GithubIcon = createLogoIcon(githubLightIcon, {
  monochromatic: true,  // 내부적으로 dark:invert 적용
});

// ❌ 잘못된 방법 - 수동 다크 모드 재정의
<div className="bg-white dark:bg-black text-black dark:text-white">
  콘텐츠
</div>
```

---

## 6. className 유틸리티

**className에는 원시 문자열 포매팅 대신 `cn` 유틸리티를 사용하세요.**

**이유:** `cn`이 더 읽기 쉽습니다. 문자열 배열과 같은 더 복잡한 타입을 올바르게 처리하고, `myCondition && "some-class"` 같은 조건부 표현식을 자연스럽게 처리합니다.

```typescript
import { cn } from '@/lib/utils'

// ✅ 올바른 방법
<div className={cn(
  'base-class',
  isActive && 'active-class',
  className
)}>
  콘텐츠
</div>

// ❌ 잘못된 방법
<div className={`base-class ${isActive ? 'active-class' : ''} ${className}`}>
  콘텐츠
</div>
```

---

## 7. 커스텀 훅 구성

**"훅 파일당 하나" 레이아웃을 따르세요. 각 훅은 `web/src/hooks` 내의 별도 파일에 있어야 합니다.**

**이유:** 레이아웃 선호도입니다. 코드를 깔끔하게 유지합니다.

```typescript
// web/src/hooks/useUserData.ts
export function useUserData(userId: string) {
  // 훅 구현
}

// web/src/hooks/useLocalStorage.ts
export function useLocalStorage<T>(key: string, initialValue: T) {
  // 훅 구현
}
```

---

## 8. 아이콘 사용

**`web/src/icons` 디렉토리의 아이콘만 사용하세요. `react-icons`, `lucide` 또는 다른 외부 라이브러리의 아이콘을 사용하지 마세요.**

**이유:** Onyx 가이드라인에 맞는 신중하게 선별된 아이콘 세트를 보유하고 있습니다. 다른 미적 스타일로 혼탁하게 만들고 싶지 않습니다.

```typescript
// ✅ 올바른 방법
import SvgX from "@/icons/x";
import SvgMoreHorizontal from "@/icons/more-horizontal";

// ❌ 잘못된 방법
import { User } from "lucide-react";
import { FiSearch } from "react-icons/fi";
```

**누락된 아이콘**: 필요한 아이콘이 `web/src/icons` 디렉토리에 없는 경우, Figma MCP 도구를 사용하여 Figma에서 가져와 아이콘 디렉토리에 추가하세요. 도움이 필요하면 `raunak@onyx.app`에 문의하세요.

---

## 9. 텍스트 렌더링

**모든 텍스트 렌더링에는 `refresh-components/texts/Text` 컴포넌트를 사용하세요. "네이키드" 텍스트 노드를 피하세요.**

**이유:** `Text` 컴포넌트는 Figma에서 제공된 스타일링을 완전히 준수합니다. 플래그 형태로 텍스트 색상과 폰트 크기를 지정하는 편리한 유틸리티를 제공합니다.

```typescript
// ✅ 올바른 방법
import { Text } from '@/refresh-components/texts/Text'

function UserCard({ name }: { name: string }) {
  return (
    <Text
      text03      // 3번째 스케일 회색으로 텍스트 색상 설정
      mainAction  // Figma에 설명된 "main-action" 폰트 + 줄 높이 + 두께
    >
      {name}
    </Text>
  )
}

// ❌ 잘못된 방법
function UserCard({ name }: { name: string }) {
  return (
    <div>
      <h2>{name}</h2>
      <p>사용자 상세 정보</p>
    </div>
  )
}
```

---

## 10. 컴포넌트 사용

**원시 HTML 입력 컴포넌트를 최대한 피하세요. `web/src/refresh-components` 또는 `web/lib/opal/src` 디렉토리의 컴포넌트를 항상 사용하세요.**

**이유:** Onyx 앱에서 렌더링되는 컴포넌트를 통일하기 위해 많은 노력을 기울였습니다. 원시 컴포넌트를 사용하면 전체 UI가 깨집니다.

```typescript
// ✅ 올바른 방법
import Button from '@/refresh-components/buttons/Button'
import InputTypeIn from '@/refresh-components/inputs/InputTypeIn'
import SvgPlusCircle from '@/icons/plus-circle'

function ContactForm() {
  return (
    <form>
      <InputTypeIn placeholder="검색..." />
      <Button type="submit" leftIcon={SvgPlusCircle}>제출</Button>
    </form>
  )
}

// ❌ 잘못된 방법
function ContactForm() {
  return (
    <form>
      <input placeholder="이름" />
      <textarea placeholder="메시지" />
      <button type="submit">제출</button>
    </form>
  )
}
```

---

## 11. 색상

**Tailwind CSS 기본 색상 대신 커스텀 재정의 색상과 테두리를 항상 사용하세요. 이 재정의는 `web/tailwind-themes/tailwind.config.js`에 있습니다.**

**이유:** 커스텀 색상 시스템은 자동으로 다크 모드를 처리하고 앱 전반에 걸쳐 디자인 일관성을 유지하는 CSS 변수를 사용합니다.

**사용 가능한 색상 카테고리:**

| 카테고리 | 클래스 예시 |
|----------|------------|
| **텍스트** | `text-01` ~ `text-05`, `text-inverted-XX` |
| **배경** | `background-neutral-XX`, `background-tint-XX` |
| **테두리** | `border-01` ~ `border-05`, `border-inverted-XX` |
| **액션** | `action-link-XX`, `action-danger-XX` |
| **상태** | `status-info-XX`, `status-success-XX`, `status-warning-XX`, `status-error-XX` |
| **테마** | `theme-primary-XX`, `theme-red-XX`, `theme-blue-XX` |

```typescript
// ✅ 올바른 방법 - 커스텀 Onyx 색상 클래스 사용
<div className="bg-background-neutral-01 border border-border-02" />
<div className="bg-status-success-01" />
<div className="bg-action-link-01" />

// ❌ 잘못된 방법 - 표준 Tailwind 색상 사용 금지
<div className="bg-gray-100 border border-gray-300 text-gray-600" />
<div className="bg-white border border-slate-200" />
<div className="bg-green-100 text-green-700" />
```

---

## 12. 데이터 페칭

**데이터 페칭에는 `useSWR`을 선호하세요. 데이터는 일반적으로 클라이언트 사이드에서 가져와야 합니다. 데이터가 필요한 컴포넌트는 데이터를 기다리는 동안 로더/플레이스홀더를 표시해야 합니다. 최상위 레벨이 아닌 필요한 컴포넌트에서 데이터를 로드하세요.**

**이유:** 클라이언트 사이드 페칭은 데이터를 기다리지 않고 페이지 스켈레톤을 로드할 수 있게 하여 더 빠른 UX를 제공합니다. 필요한 곳에서 데이터를 로드하면 컴포넌트와 부모 컴포넌트 간의 의존성이 줄어듭니다.
