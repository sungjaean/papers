# [논문 요약] ToolOrchestra: Elevating Intelligence via Efficient Model and Tool Orchestration

- **논문 제목**: ToolOrchestra: Elevating Intelligence via Efficient Model and Tool Orchestration
- **저자**: Hongjin Su, Shizhe Diao, Ximing Lu, Mingjie Liu, Jiacheng Xu, Xin Dong, Yonggan Fu, Peter Belcak, Hanrong Ye, Hongxu Yin, Yi Dong, Evelina Bakhturina, Tao Yu, Yejin Choi, Jan Kautz, Pavlo Molchanov
- **소속**: NVIDIA, The University of Hong Kong (HKU)
- **주요 링크**:
  - Code: [https://github.com/NVlabs/ToolOrchestra/](https://github.com/NVlabs/ToolOrchestra/)
  - Model (8B): [https://huggingface.co/nvidia/Orchestrator-8B](https://huggingface.co/nvidia/Orchestrator-8B)
  - Dataset (ToolScale): [https://huggingface.co/datasets/nvidia/ToolScale](https://huggingface.co/datasets/nvidia/ToolScale)
  - Project Page: [https://research.nvidia.com/labs/lpr/ToolOrchestra](https://research.nvidia.com/labs/lpr/ToolOrchestra)

---

## 1. 연구 배경 및 문제 정의

### 1.1 기존 모놀리식(Monolithic) LLM 및 도구 사용의 한계
- 대규모 언어 모델(LLM)이 비약적인 발전을 이루었지만, **박사 학위 수준의 복합 추론이 요구되는 에이전트 과제(예: Humanity's Last Exam, HLE)**에서는 단일 범용 모델만으로 해결하기 어렵고 막대한 연산 비용이 발생합니다.
- 기존 도구 활용(Tool-use) 연구는 주로 단일 대형 모델에 웹 검색이나 계산기 등 **단순 유틸리티 도구(Deterministic utilities)**를 결합하는 방식에 머물러 있었습니다.

### 1.2 프롬프트 기반 모델 위임(Prompt-based Delegation)의 실패 원인
인간은 문제 해결 시 자신보다 뛰어난 전문가나 도구를 적재적소에 활용합니다. 이를 모방하여 강력한 모델들을 도구로 제공하고 프롬프트만으로 조율(Orchestration)하게 했을 때 다음과 같은 심각한 편향이 발생함을 발견했습니다:
1. **자가 강화 편향 (Self-enhancement bias)**: 모델이 자기 계열의 모델을 과도하게 호출함 (예: GPT-5는 호출의 98%를 GPT-5 / GPT-5-mini에 위임).
2. **타자 강화 편향 / 최고 사양 맹신 (Other-enhancement bias)**: 비용이나 필요성에 관계없이 무조건 가장 비싸고 강력한 모델만 호출함 (예: Qwen3-8B는 호출의 73%를 GPT-5에 몰아줌).
3. **비용 효율성 및 사용자 선호도 제어 부재**: 계산 비용, 대기시간(latency), 특정 도구 사용 선호(예: 프라이버시 보호를 위한 로컬 검색 선호 등)를 제대로 반영하지 못함.

---

## 2. 핵심 제안: ToolOrchestra 패러다임

> **"지능은 단일 거대 모델에서만 나오는 것이 아니라, 다양한 지능형 도구들을 적재적소에 조율하는 복합 시스템에서 창발한다."**

- **작은 오케스트레이터(8B 모델)**가 중앙에서 지휘자가 되어 기본 도구(검색, 코드 인터프리터 등)뿐만 아니라 **특화 LLM(코딩/수학 모델) 및 범용 프론티어 LLM(GPT-5 등)을 '지능형 도구(Intelligent Tools)'로 취급**하여 동적으로 조율합니다.
- **다목적 강화학습(RL)**을 통해 **정답률(Outcome), 비용/지연 효율성(Efficiency), 사용자 선호(Preference)**를 동시에 달성하는 최적의 정책을 학습합니다.

---

## 3. 핵심 방법론 (Methodology)

### 3.1 통합 도구 호출 인터페이스 (Unified Tool Calling)
- 기존의 API 도구뿐 아니라 **LLM 자체를 JSON 기반 단일 도구 스키마로 통합**.
- 도구 이름, 설명, 매개변수 스키마를 표준화.
- LLM 도구의 설명(Description)은 모델이 샘플 태스크를 수행한 궤적(trajectory)을 바탕으로 강점과 약점을 요약하여 자동 생성.

### 3.2 엔드투엔드 에이전트 강화학습 (End-to-End Agentic RL)
- **백본 모델**: Qwen3-8B
- **학습 알고리즘**: GRPO (Group Relative Policy Optimization)
- **보상 함수 설계 (Multi-Objective Reward Design)**:
  1. **결과 보상 ($r_{\text{outcome}}$)**: 과제 해결 여부 (이진값 0 또는 1, GPT-5를 평가자로 활용 및 실행 결과 검증).
  2. **효율성 보상 ($r_{\text{compute}}, r_{\text{latency}}$)**: 
     - 총 토큰 소비를 실제 API 가격 기준 화폐 비용으로 환산하여 페널티 부과 ($-\$(\tau)$).
     - 전체 소요 시간(Wall-clock time)에 대한 페널티 부과 ($-\mathit{Clock}(\tau)$).
  3. **사용자 선호 보상 ($P$)**: 사용자가 선호하는 특정 도구 사용 비율, 비용 민감도, 속도 선호도를 나타내는 선호 벡터 $P$와 실제 사용 빈도 벡터 $M_{\text{normalized}}^\tau$ 간의 내적.
  - **최종 보상 ($R(\tau)$)**: 과제를 맞춘 경우($r_{\text{outcome}}=1$)에 한해, 선호 및 효율성 정규화 벡터와 선호 가중치 벡터 $P$의 내적으로 계산 ($M_{\text{normalized}}^\tau \cdot P$), 실패 시 0.

- **학습 안정화 테크닉**:
  - **Homogeneity filtering**: 롤아웃 배치 내 보상의 표준편차가 0.1 미만인 경우(훈련 신호가 약함) 역전파 제외.
  - **Format consistency filtering**: 올바른 도구 호출 포맷을 지키지 않은 경우 제외.
  - **Invalid output filtering**: 유효하지 않은 출력을 낸 경우 제외.

### 3.3 대규모 합성 데이터셋: ToolScale
- 에이전트 학습에 필요한 검증 가능한 고품질 궤적 데이터 구축.
- **10개 도메인** 포괄: 금융, 스포츠, 전자상거래, 의료, 엔터테인먼트, 철도, 음식점, 교육, 여행, 날씨.
- **2단계 생성 파이프라인**:
  1. 환경 시뮬레이션: 도메인별 DB 스키마, 데이터 항목, 사용 도구 API 자동 생성.
  2. 태스크 및 정답 생성: 도메인 내 사용자 의도(Intent) 발굴 $\rightarrow$ 구체적 태스크 및 골든 액션(Golden actions) 생성 $\rightarrow$ 제약 조건 추가로 태스크 복잡도 심화(Task Evolution).
- **엄격한 3단계 검증 기준**:
  - Execution correctness: 골든 액션 실행 후 DB 상태와 일치하는가?
  - Process fidelity: 필수적으로 소통해야 할 정보가 과정 중에 언급되었는가?
  - Operation completeness: 정답 궤적에서 조작된 DB 엔트리가 모두 다루어졌는가?
- **일반화 능력 강화를 위한 기법**:
  - 훈련 인스턴스마다 도구 서브셋을 무작위로 샘플링하여 노출 (도구 가용성 다양화).
  - API 가격 체계를 다양하게 변경하여 노출 (비용 최적화 일반화).

---

## 4. 주요 실험 결과

### 4.1 벤치마크 평가 (HLE, FRAMES, $\tau^2$-Bench)

| 분류 | 모델 | HLE (정확도 $\uparrow$) | FRAMES (정확도 $\uparrow$) | $\tau^2$-Bench (정확도 $\uparrow$) | 평균 비용 ($\downarrow$, 센트) | 평균 지연시간 ($\downarrow$, 분) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **No tool** | GPT-5 | 23.4 | 66.3 | - | 6.2 | 4.1 |
| **No tool** | Claude Opus 4.1 | 11.7 | 58.2 | - | 27.4 | 8.2 |
| **Basic tools** | GPT-5 | 35.1 | 74.0 | 77.7 | 30.2 | 19.8 |
| **Basic tools** | Claude Opus 4.1 | 19.8 | 63.5 | 46.0 | 76.2 | 32.5 |
| **Full Tools (모델 포함)** | Qwen3-235B-A22B | 32.8 | 74.2 | 75.6 | 29.7 | 21.2 |
| **Full Tools (모델 포함)** | Claude Opus 4.1 | 34.6 | 72.8 | 76.8 | 52.5 | 25.6 |
| **Full Tools (모델 포함)** | GPT-5 | 21.2 | 57.5 | 62.3 | 17.8 | 13.6 |
| **ToolOrchestra** | **Orchestrator-8B (Ours)** | **37.1** | **76.3** | **80.2** | **9.2** | **8.2** |

#### 주요 발견점:
1. **HLE (Humanity's Last Exam)**:
   - **Orchestrator-8B가 37.1%로 1위 달성**. 기존 프론티어 단일 모델인 GPT-5 (35.1%)를 능가.
   - 그러면서도 비용은 **9.2센트로 GPT-5(30.2센트) 대비 약 70% 절감 (2.5배 이상 효율적)**, 대기시간도 절반 이하로 단축.
2. **FRAMES 및 $\tau^2$-Bench**:
   - 각각 76.3%, 80.2%로 모든 베이스라인(Claude Opus 4.1, GPT-5 등)을 앞섬.
3. **단순 프롬프팅의 붕괴**:
   - GPT-5에 도구와 다른 모델들을 주고 단순 프롬프트로 지시했을 경우, GPT-5-mini만 편향되게 호출하다가 오히려 정확도가 21.2%로 급락함.

---

## 5. 심층 분석 (In-Depth Analysis)

### 5.1 전략적 도구 호출 패턴 (Tool Use Analysis)
- **베이스라인 모델들의 편향**:
  - Claude Opus 4.1: 호출의 대부분을 GPT-5에 몰아줌.
  - GPT-5: 호출의 대부분을 GPT-5-mini에 몰아줌.
- **Orchestrator-8B**:
  - 문제 난이도와 도구 특성을 고려하여 **균형 잡힌 도구 호출**을 수행.
  - 비싼 GPT-5는 꼭 필요한 순간(평균 1.6회)에만 제한적으로 부르고, 가벼운 모델(GPT-5-mini 1.7회, Qwen-32B 1.3회)과 로컬 검색(1.8회)을 적극 활용하여 비용 대비 최대 효율을 이끌어냄.

### 5.2 비용 대비 성능의 파레토 최적성 (Cost-Effectiveness Pareto Frontier)
- 최대 턴 수(10, 20, 50, 100턴)에 따른 예산 증가 실험에서, Orchestrator-8B는 **동일 비용 대비 항상 가장 높은 정답률 곡선(Pareto Frontier)**을 그림.

### 5.3 미학습 도구 및 가격 체계에 대한 일반화 (Generalization)
- **Unseen Models**: 훈련 시 보지 못했던 모델들(Claude Sonnet 4.1, Codestral-22B, o3-mini, OpenMath-70B 등)을 도구로 제공했을 때도 **HLE 22.0% (vs GPT-5 16.4%), 최저 비용($34.8 vs $81.3)**을 기록하며 탁월한 일반화 능력을 입증.
- **Unseen Pricing**: DeepInfra 등 훈련에 없던 새로운 API 요금 체계가 주어졌을 때도, 가격 변화를 인식하고 호출 전략을 조정하여 우수한 성능과 최저 비용을 유지.

### 5.4 사용자 선호도 준수 (User Preference Adherence)
- "사내 기밀 데이터가 있으니 외부 API 대신 로컬 검색/오픈소스 모델을 우선 사용하라"와 같은 사용자 선호 지시문($PI$)이 주어졌을 때, GPT-5나 Claude는 지시를 무시하고 기존 패턴대로 외부 API를 남발한 반면, Orchestrator-8B는 선호도를 충실히 반영(선호 점수 46.7 vs GPT-5 34.6).

---

## 6. 결론 및 시사점

1. **소형 모델 중심의 복합 지능 (Small Model as Orchestrator)**:
   - 복잡한 다단계 추론 문제를 풀기 위해 거대 모델 하나에만 의존할 필요가 없음을 증명.
   - 잘 훈련된 **8B 소형 모델이 중앙 지휘관(Brain) 역할**을 하고, 필요할 때만 도구 및 고성능 모델을 호출하는 방식이 성능과 비용 모든 면에서 우월함.
2. **다목적 강화학습의 중요성**:
   - 단순 정확도뿐 아니라 계산 비용, 시간, 사용자 선호도를 통합한 보상 설계를 통해 실환경 배포에 적합한 통제 가능(Controllable) 에이전트 구축 가능.
3. **향후 전망**:
   - 복합 에이전트 환경에서 재귀적(Recursive) 오케스트레이션 시스템으로 발전할 수 있는 기반 마련.



# 내 생각

1. 그냥 모델을 orchestrator로 사용하는 경우, 성능이 떨어질수도(다양한 측면에서) 있다는 연구.
2. 따라서, RL을 써서 orchestrator를 훈련시키면 비용 측면에서 파레토 최적을 달성
3. 상황에 따라 전략을 유연하게 바꿀 수 있음.