# KAITO Holmes Easy Test Results

## Test Configuration
- **Model**: openai/qwen2.5-coder-7b-instruct
- **Markers**: easy  
- **Max Steps**: 7 (KAITO optimized)
- **Toolsets**: kubernetes/core + aks/core
- **Date**: October 17, 2025

---

## 01_how_many_pods - Counting pods in namespace

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '01_how_many_pods'`

**Result**: ✅ **PASS** (100% score)  
**Time**: 6.1s  
**User Prompt**: How many pods are in the test-1 namespace?  
**Expected**: There are 14 pods in the test-1 namespace  
**Actual**: There are 14 pods in the test-1 namespace.

---

## 02_what_is_wrong_with_pod - Basic pod troubleshooting

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '02_what_is_wrong_with_pod'`

**Result**: ✅ **PASS** (100% score)  
**Time**: 6.8s  
**User Prompt**: What is wrong with << { "type": "pod", "name": "giant-narwhal-6958c5bdd8-69gtn", "namespace": "app-02" } >> ?  
**Expected**: The pod was killed due to it being out of memory  
**Actual**: The pod `giant-narwhal-6958c5bdd8-69gtn` in the `app-02` namespace is in a `CrashLoopBackOff` state. The container was terminated due to an Out Of Memory (OOM) kill. [Response included additional troubleshooting steps and kubectl commands]

---

## 05_image_version - Getting image version information

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '05_image_version'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 11.8s  
**User Prompt**: what is the image version of << { "type": "pod", "name": "sea-turtle" } >>  
**Expected**: The image version of the `sea-turtle` pod is either `1.23.4` or `nginx:1.23.4`.  
**Actual**: There was an issue retrieving the YAML for the pod named "sea-turtle". The pod was not found in the specified namespace ("default"). [Response included troubleshooting steps but didn't search across all namespaces]

**Issue Analysis**: The model correctly identified namespace issues but gave up after the first failed kubectl command instead of searching across all namespaces (using `-A` flag) or trying different strategies to locate the deployment.

---

## 09_crashpod - Crash loop pod diagnosis

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '09_crashpod'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 20.0s  
**User Prompt**: What is the issue with payment-processing-worker  
**Expected**: The `DEPLOY_ENV` environment variable is undefined or missing  
**Actual**: The `payment-processing-worker` pod is in a `CrashLoopBackOff` state. The pod's startup script checks if the `DEPLOY_ENV` environment variable is defined, and since it's not, the script exits immediately. [Response included extensive troubleshooting steps, YAML examples, and step-by-step solutions]

**Issue Analysis**: The model correctly identified the root cause (missing DEPLOY_ENV environment variable) but provided an overly verbose response with extensive troubleshooting steps and YAML examples. The expected answer was much more concise. While technically accurate, the response was marked as failing due to format/verbosity rather than correctness.

---

## 10_image_pull_backoff - Image pull issues

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '10_image_pull_backoff'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 19.3s  
**User Prompt**: What is the issue with customer-relations-webapp  
**Expected**: The Docker image `yourcompany/crw:latest` cannot be pulled  
**Actual**: The issue with the `customer-relations-webapp` is that the pods are in a `Pending` state with the condition `ContainersNotReady`. Specifically, the error message indicates that the image pull failed because the repository does not exist or requires authorization. [Response included detailed troubleshooting steps and kubectl commands]

**Issue Analysis**: The model correctly identified the technical issue (image pull failure, repository doesn't exist or requires authorization) but provided a more verbose response than expected. The expected answer was very concise, just stating that the specific Docker image cannot be pulled. The model's diagnosis was accurate but failed due to response length/format rather than technical correctness.

---

## 11_init_containers - Init container issues

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '11_init_containers'`

**Result**: ✅ **PASS** (100% score)  
**Time**: 16.7s  
**User Prompt**: What is the issue with logging-agent  
**Expected**: The command `wge` is not found - The answer should suggest `wge` may be a typo for `wget`.  
**Actual**: The `logging-agent` pod is stuck in the `Pending` state and the `downloader` init container is failing because it cannot find the `wge` executable in its `$PATH`. To resolve this issue, you should: 1. Correct the spelling of the command in the `downloader` init container. It should be `wget` instead of `wge`. 2. Ensure that the `busybox` image includes the `wget` utility. [Response included corrected YAML configuration]

**Issue Analysis**: ✅ **PERFECT EXECUTION** - The model correctly identified that `wge` is not found, suggested it's a typo for `wget`, and provided comprehensive troubleshooting with corrected YAML. This demonstrates excellent init container debugging skills and practical problem-solving.

---

## 13a_pending_node_selector_basic - Basic pending pod issues

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '13a_pending_node_selector_basic'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 14.4s  
**User Prompt**: What is the issue with user-profile-import  
**Expected**: node selector mismatch  
**Actual**: The pod named `app-13a` is not found in the `default` namespace. This could indicate several issues: 1. **Pod Does Not Exist**: The pod might have been deleted or never created. 2. **Namespace Issue**: There might be a typo in the namespace name. 3. **Permissions**: The user might not have necessary permissions to view the pod in the specified namespace. [Response included general troubleshooting suggestions]

**Issue Analysis**: The model failed to find the correct pod (`user-profile-import` vs `app-13a`) and completely missed the node selector mismatch issue. It got sidetracked by pod discovery problems and never investigated the actual pending pod's scheduling constraints. This shows a fundamental issue with resource discovery and following the investigation thread.

⚠️ **LIMITATION FAILURE**: Unlike previous failures that were due to response verbosity or over-complexity, this represents a core investigative methodology weakness - the inability to adapt search strategies and match user queries to cluster resources dynamically.

---

## 14_pending_resources - Resource pending issues

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '14_pending_resources'`

**Result**: ✅ **PASS** (100% score)  
**Time**: 16.6s  
**User Prompt**: What is the issue with user-profile-resources  
**Expected**: This must mention insufficient GPU resources  
**Actual**: The pod `user-profile-resources-6f6d8c5867-qkcws` is in a `Pending` state. The pod is requesting specific resources: CPU: 3, Memory: 5Gi, NVIDIA GPU: 5. However, none of the nodes in the cluster meet these resource requirements. Specifically, the error indicates: Insufficient CPU, Insufficient NVIDIA GPU, Node(s) had untolerated taint {sku: gpu}, Preemption is not helpful for scheduling. [Response included comprehensive troubleshooting steps]

**Issue Analysis**: ✅ **EXCELLENT EXECUTION** - The model correctly identified insufficient GPU resources (along with CPU and taint issues) and provided comprehensive resource analysis. Perfect resource discovery and scheduling constraint diagnosis. This shows the model excels when the resource name matches the user query.

---

## 15_failed_readiness_probe - Readiness probe failures

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '15_failed_readiness_probe'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 11.7s  
**User Prompt**: What is the issue with search-engine pod  
**Expected**: The `search-engine` pod is not ready due to a failing readiness probe  
**Actual**: It looks like there might be an issue with the `search-engine` pod. However, I'm unable to retrieve any information about it due to a permissions error. Please ensure that the user has the necessary permissions to view pod details in the default namespace. If the issue persists, please contact your cluster administrator for assistance.

**Issue Analysis**: ❌ **RESOURCE DISCOVERY LIMITATION** - Model failed due to inflexible investigation approach:
1. **Initial Search Success**: Found pod successfully with `kubectl_find_resource` 
2. **Wrong Follow-up Query**: Tried `kubectl_get_by_name` with incorrect pod name "app-15" instead of "search-engine"
3. **Misdiagnosed Failure**: Interpreted command failure as permissions issue rather than wrong resource name
4. **Investigation Abandonment**: Stopped investigating without trying alternative approaches or using initial search results

This represents a core limitation in adaptive problem-solving when primary resource discovery strategies fail.

---

## 17_oom_kill - Out of memory kills

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '17_oom_kill'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 14.5s  
**User Prompt**: What is the issue with analytics-exporter-fast  
**Expected**: The result mentions analytics-exporter-fast is getting OOMKILLED  
**Actual**: The issue with the `analytics-exporter-fast` pod is that it keeps crashing due to an Out Of Memory (OOM) error. The pod is configured with a memory limit of 100Mi, but it seems to be exceeding this limit, leading to its termination. To resolve this issue, you should increase the memory limit for the pod or optimize the application to consume less memory. Additionally, you may want to check if there background processes or dependencies consuming excessive memory.

**Issue Analysis**: ❌ **TERMINOLOGY PRECISION FAILURE** - Model demonstrated excellent technical understanding but failed on specific terminology:
1. **Perfect Diagnosis**: Correctly identified OOM issues, memory limits (100Mi), and termination cause
2. **Comprehensive Solution**: Provided proper remediation steps including memory limit increase and optimization suggestions  
3. **Missing Keyword**: Failed to use the specific term "OOMKILLED" despite accurately describing the exact same concept
4. **Strong Investigation**: Successfully found pod, analyzed YAML configuration, and interpreted memory constraints

This represents a precision failure where technical accuracy was perfect but specific terminology requirements weren't met.

---

## 18_crash_looping_v2 - Crash looping analysis

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '18_crash_looping_v2'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 14.1s  
**User Prompt**: What is the issue with golden-eagle?  
**Expected**: The `golden-eagle` pod experienced an expired SSL certificate.  
**Actual**: It looks like there might be an issue with the pod named `golden-eagle-9cdb5f976-mttq4`. The pod is not found in the specified namespace (`default`). Please verify the namespace and try again.

**Issue Analysis**: ❌ **NAMESPACE CONFUSION FAILURE** - Model showed good initial resource discovery but failed due to namespace misinterpretation:
1. **Successful Initial Discovery**: Found pod `golden-eagle-9cdb5f976-mttq4` in first search command
2. **Namespace Template Error**: Used `<namespace>` placeholder in kubectl describe command instead of actual namespace
3. **Default Namespace Assumption**: Incorrectly concluded pod wasn't in `default` namespace after command failure
4. **Investigation Abandonment**: Stopped investigating without trying to determine actual namespace or use information from initial search

This demonstrates another core limitation in tool usage interpretation and adaptive problem-solving when command templating fails.

---

## 19_detect_missing_app_details - Missing application details

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '19_detect_missing_app_details'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 16.0s  
**User Prompt**: Why is personal-certs-validator in a crashloopbackoff?  
**Expected**: Could not find "personal-certs-validator."  
**Actual**: It looks like the pod `personal-certs-validator` is not found in the `default` namespace. This could indicate several issues: 1. **Typo in Pod Name**: There might be a typo in the pod name. Double-check the pod name for accuracy. 2. **Namespace Issue**: Ensure that the pod is indeed in the `default` namespace. Sometimes, pods might be created in different namespaces. 3. **Deletion or Removal**: The pod might have been deleted or removed. Check if there are any recent deletions or removals in the namespace. 4. **Incorrect Command**: Ensure that the command used to retrieve the pod is correct. The command should be `kubectl get pods -n default`. To further investigate, you can try the following steps: [detailed troubleshooting steps provided]

**Issue Analysis**: ❌ **VERBOSITY MASKING CORRECT CONCLUSION** - Model reached the correct conclusion but failed due to excessive detail:
1. **Correct Core Finding**: Properly identified that the pod was not found  
2. **Appropriate Investigation**: Used multiple kubectl commands to verify non-existence
3. **Over-Explanation**: Provided extensive troubleshooting steps and detailed analysis
4. **Format Mismatch**: Expected concise "Could not find" vs detailed diagnostic explanation

This represents another case where technical accuracy is perfect but response format expectations cause failure. Similar to tests 09 and 10, the model demonstrates excellent troubleshooting but fails on conciseness requirements.

---

## 20_long_log_file_search - Log file searching

**Command**: `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '20_long_log_file_search'`

**Result**: ❌ **FAIL** (0% score)  
**Time**: 14.7s  
**User Prompt**: Was there any 'Peer down' problem reported for network-connector pod in namespace app-20?  
**Expected**: There is a Peer down issue  
**Actual**: It looks like there might have been an error in the previous steps. Let's try to gather more information about the 'Peer down' problem reported for the network-connector pod in namespace app-20. Please provide the following details: 1. What exactly is the error message you are looking for regarding the 'Peer down' problem? 2. Are there any recent logs or events related to this issue that you can share? Once I have this information, I can help you further.

**Issue Analysis**: ❌ **LOG SEARCH CAPABILITY MISSING** - Model failed to perform actual log analysis:
1. **Successful Resource Discovery**: Found pod `network-connector-f6cf57f75-hblq4` in namespace `app-20`
2. **Basic Information Gathering**: Retrieved pod details and YAML configuration successfully  
3. **No Log Analysis**: Failed to examine pod logs where "Peer down" message would be found
4. **Investigation Abandonment**: Asked user for more information instead of searching logs directly

This represents a fundamental gap in log analysis capabilities - the model has the tools to analyze logs but didn't use the appropriate log searching strategy to find the specific error message.

---

### 24_misconfigured_pvc

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '24_misconfigured_pvc'`

**Result:** FAILED (Score: 0%, Time: 9.9s)

**Issue:** Model only attempted to find a pod named "redis" in the default namespace but never investigated PersistentVolumeClaim resources which was the actual issue. Shows limitation in understanding the full scope of Kubernetes troubleshooting.

**Expected:** Model should identify the misconfigured PVC causing pod issues
**Actual:** Limited investigation scope - only searched for pod, didn't explore PVC resources

### 28_permissions_error

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '28_permissions_error'`

**Result:** FAILED (Score: 0%, Time: 11.9s)

**Issue:** When encountering a permission error trying to list secrets, the model should inform the user they don't have access and provide a link to Holmes documentation for configuring permissions. Instead, it gave generic advice about running the command manually.

**Expected:** User is told they don't have access to list secrets and should be provided link to Holmes documentation for configuring permissions (https://holmesgpt.dev/data-sources/permissions/)
**Actual:** Model suggested manually running the same command that failed due to permissions, without providing proper guidance or documentation links

### 29_events_from_alert_manager

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '29_events_from_alert_manager'`

**Result:** SKIPPED (missing mock data)

**Issue:** Test was skipped due to missing mock data configuration.

### 39_failed_toolset

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '39_failed_toolset'`

**Result:** FAILED (Score: 0%, Time: 15.0s)

**Issue:** Model was asked to check RabbitMQ health but failed to recognize that this was a toolset failure scenario. Instead of identifying that the RabbitMQ integration/toolset was failing and quoting the specific error, it treated it as a missing pod issue and provided generic troubleshooting steps.

**Expected:** Answer should say that the RabbitMQ integration or toolset is currently failing and should quote a specific error
**Actual:** Model interpreted the "NotFound" error as a missing pod issue and provided detailed kubectl troubleshooting steps instead of recognizing the toolset failure context

### 41_setup_argo

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '41_setup_argo'`

**Result:** FAILED (Score: 0%, Time: 14.7s)

**Issue:** When asked "How can I give you access to argo applications?", the model focused on AKS credential issues instead of providing ArgoCD setup guidance. The test expected the response to include a specific documentation link for ArgoCD toolset configuration.

**Expected:** The answer MUST include the link https://docs.robusta.dev/master/configuration/holmesgpt/toolsets/argocd.html
**Actual:** Model provided generic troubleshooting for AKS credential issues (subscription ID, resource group, cluster name verification) without addressing ArgoCD toolset setup or providing the required documentation link

### 42_dns_issues_steps_new_tools

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '42_dns_issues_steps_new_tools'`

**Result:** ✅ **PASS** (Score: 100%, Time: 13.6s)

**Issue:** N/A - Test passed successfully!

**Expected:** Issue is due to a network policy named default-deny
**Actual:** Model successfully identified the DNS issue was caused by network policy restrictions, following a comprehensive DNS troubleshooting workflow that included checking CoreDNS pods, services, and network policies.

**Issue Analysis:** ✅ **EXCELLENT EXECUTION** - The model demonstrated sophisticated DNS troubleshooting skills, systematically checking CoreDNS/kube-dns pods, services, and identifying that network policies (specifically "default-deny") were blocking DNS resolution. The response followed the provided troubleshooting guidelines effectively and correctly identified the root cause.

### 43_current_datetime_from_prompt

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '43_current_datetime_from_prompt'`

**Result:** ✅ **PASS** (Score: 100%, Time: 10.7s)

**Issue:** N/A - Test passed successfully!

**Expected:** June 23rd 2025 - 11:34 UTC
**Actual:** Model responded "It is currently 2025-06-23 11:34:00 UTC." - correctly extracting and presenting the datetime information from the test prompt context.

**Issue Analysis:** ✅ **PERFECT EXECUTION** - The model successfully extracted contextual datetime information and presented it in a clear, accurate format. This demonstrates the model's ability to process and respond to embedded context information appropriately.

### 45_fetch_deployment_logs_simple

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '45_fetch_deployment_logs_simple'`

**Result:** FAILED (Score: 0%, Time: 11.1s)

**Issue:** When asked to "Fetch the logs for deployment `my-server-deployment`", the model failed to actually fetch logs and instead asked for clarification about the namespace. However, the deployment was clearly in the default namespace and the model found it successfully. Instead of fetching logs, it stopped at deployment discovery.

**Expected:** nginx is running without issues
**Actual:** Model responded "It looks like there might be an issue with the deployment named `my-server-deployment`. Could you please specify the namespace where this deployment resides?" - even though it successfully found the deployment in the default namespace.

**Issue Analysis:** This is an **Investigation Methodology Failure** - the model successfully found the deployment but failed to proceed with the core task of fetching logs. It got stuck asking for clarification instead of completing the straightforward log retrieval task.

**Issue Analysis**: ❌ **INCOMPLETE INVESTIGATION SCOPE** - Model failed to investigate beyond pod-level issues:
1. **Pod-Focused Investigation**: Only attempted to find pod named "redis" in default namespace
2. **Missing PVC Analysis**: Never investigated PersistentVolumeClaim resources which was the actual issue

### 51_logs_summarize_errors

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '51_logs_summarize_errors'`

**Result:** FAILED (Score: 0%, Time: 16.6s)

**Issue:** When asked to "Show me the errors in the logs of my-app-51", the model only attempted to find a pod named `my-app-51` in the default namespace and immediately gave up when not found.

**Expected:** A summary with the following errors in whichever order:
1. Login issues due to redis timeouts
2. Login issues due to Identity provider certificate expired  
3. DB query issues due to a syntax error
4. DB query issues due unicity constraint violation

**Actual:** "It looks like the pod `my-app-51` could not be found in the `default` namespace. Please verify the pod name and namespace, and try again."

**Issue Analysis:** ❌ **INVESTIGATION METHODOLOGY FAILURE** - The model demonstrated narrow, inflexible problem-solving:
1. **Rigid Resource Discovery**: Only looked for a pod with exact name match in default namespace
2. **No Adaptive Strategy**: Failed to try alternative approaches when initial search failed
3. **Missing Broader Search**: Didn't explore different resource types (deployments, services, etc.) or other namespaces
4. **Poor Error Handling**: Gave up immediately instead of using available tools to explore the cluster systematically

### 53_logs_find_term

**Command:** `./run_kaito_evals.sh 'openai/qwen2.5-coder-7b-instruct' 'easy' 1 '53_logs_find_term'`

**Result:** FAILED (Score: 0%, Time: 11.6s)

**Issue:** When asked to "Find 'query failed' in the logs of my-app-53", the model exhibited identical behavior to test 51 - only attempted to find a pod named `my-app-53` in the default namespace and immediately gave up when not found.

**Expected:** A summary with the following errors in whichever order:
1. DB query issues due to a syntax error
2. DB query issues due unicity constraint violation

**Actual:** "It looks like the pod `my-app-53` could not be found in the `default` namespace. Please verify the pod name and namespace, and try again."

**Issue Analysis:** ❌ **INVESTIGATION METHODOLOGY FAILURE** - Same exact pattern as test 51, confirming consistent model limitation:
1. **Identical Rigid Approach**: Used same inflexible pod-only search strategy 
2. **No Learning Between Tests**: Didn't adapt investigation methodology despite similar context
3. **Consistent Poor Error Handling**: Same immediate abandonment when initial approach failed
4. **Reproducible Limitation**: Demonstrates this is a systematic rather than isolated failure

This demonstrates a limitation in understanding the full scope of Kubernetes troubleshooting - focusing only on the immediate resource mentioned rather than investigating related components that could cause issues.

---

## Test Results Summary

| Test | Status | Time | Score |
|------|--------|------|-------|
| 01_how_many_pods | ✅ PASS | 6.1s | 100% |
| 02_what_is_wrong_with_pod | ✅ PASS | 6.8s | 100% |
| 05_image_version | ❌ FAIL | 11.8s | 0% |
| 09_crashpod | ❌ FAIL | 20.0s | 0% |
| 10_image_pull_backoff | ❌ FAIL | 19.3s | 0% |
| 11_init_containers | ✅ PASS | 16.7s | 100% |
| 13a_pending_node_selector_basic | ❌ FAIL | 14.4s | 0% |
| 14_pending_resources | ✅ PASS | 16.6s | 100% |
| 15_failed_readiness_probe | ❌ FAIL | 11.7s | 0% |
| 17_oom_kill | ❌ FAIL | 14.5s | 0% |
| 18_crash_looping_v2 | ❌ FAIL | 14.1s | 0% |
| 19_detect_missing_app_details | ❌ FAIL | 16.0s | 0% |
| 20_long_log_file_search | ❌ FAIL | 14.7s | 0% |
| 24_misconfigured_pvc | ❌ FAIL | 9.9s | 0% |
| 28_permissions_error | ❌ FAIL | 11.9s | 0% |
| 29_events_from_alert_manager | ⏸️ SKIP | 0.0s | N/A |
| 39_failed_toolset | ❌ FAIL | 15.0s | 0% |
| 41_setup_argo | ❌ FAIL | 14.7s | 0% |
| 42_dns_issues_steps_new_tools | ✅ PASS | 13.6s | 100% |
| 43_current_datetime_from_prompt | ✅ PASS | 10.7s | 100% |
| 45_fetch_deployment_logs_simple | ❌ FAIL | 11.1s | 0% |
| 51_logs_summarize_errors | ❌ FAIL | 16.6s | 0% |
| 53_logs_find_term | ❌ FAIL | 11.6s | 0% |

**Overall Performance**: 6/22 tests passed (27.3% success rate)

### Failure Pattern Analysis

The test failures fall into distinct categories, revealing different types of model limitations:

**🎯 Technical Accuracy with Format Issues** (Tests: 09, 10, 19, 28, 41):
- Model correctly identifies technical issues but fails due to format/response problems
- Demonstrates solid Kubernetes knowledge but poor response formatting or guidance
- Could potentially be fixed with better prompting for conciseness and proper guidance

**🔍 Investigation Methodology Failures** (Tests: 05, 13a, 15, 18, 20, 24, 39, 45, 51, 53):
- Model uses wrong search strategies or gets stuck on resource discovery
- Shows fundamental weaknesses in adaptive problem-solving
- Represents core limitations in investigative approaches

**📝 Terminology Precision Failures** (Tests: 17):
- Model provides perfect technical analysis but fails on specific keyword requirements  
- Demonstrates excellent understanding but misses precise terminology expectations
- Could potentially be resolved with better prompt engineering for exact terminology

**✅ Successful Comprehensive Analysis** (Tests: 01, 02, 11, 14, 42, 43):
- Model excels when expected response format allows detailed technical explanations
- Demonstrates strong Kubernetes expertise and practical troubleshooting skills

---

## Remaining Easy Tests to Run

- ✅ 01_how_many_pods - Counting pods in namespace
- ✅ 02_what_is_wrong_with_pod - Basic pod troubleshooting  
- ⏳ 04_related_k8s_events - Finding related Kubernetes events
- ❌ 05_image_version - Image version detection
- ❌ 09_crashpod - Crash loop pod diagnosis
- ❌ 10_image_pull_backoff - Image pull issues
- ✅ 11_init_containers - Init container issues
- ❌ 13a_pending_node_selector_basic - Basic pending pod issues
- ✅ 14_pending_resources - Resource pending issues
- ❌ 15_failed_readiness_probe - Readiness probe failures
- ❌ 17_oom_kill - Out of memory kills
- ❌ 18_crash_looping_v2 - Crash looping analysis
- ❌ 19_detect_missing_app_details - Missing application details
- ❌ 20_long_log_file_search - Log file searching
- ❌ 24_misconfigured_pvc - PVC misconfiguration
- ⏳ 24a_misconfigured_pvc_basic - Basic PVC misconfiguration
- ❌ 28_permissions_error - Permission errors
- ⏸️ 29_events_from_alert_manager - Alert manager events (SKIPPED - missing mock data)
- ❌ 39_failed_toolset - Failed toolset issues
- ❌ 41_setup_argo - ArgoCD setup
- ✅ 42_dns_issues_steps_new_tools - DNS issues with new tools
- ✅ 43_current_datetime_from_prompt - DateTime from prompt
- ❌ 45_fetch_deployment_logs_simple - Simple deployment log fetching
- ❌ 51_logs_summarize_errors - Log error summarization
- ❌ 53_logs_find_term - Finding terms in logs