# Required Jenkins Plugins

This document lists the mandatory Jenkins plugins required to successfully execute the platform's EKS/EMR provisioning pipeline.

---

## 📋 Required Plugins List

Search and install these plugins under **Manage Jenkins** -> **Plugins** -> **Available Plugins**:

| Plugin Name | Plugin ID (Shortname) | Purpose in the Pipeline | Importance |
| :--- | :--- | :--- | :--- |
| **Pipeline** | `workflow-aggregator` | Installs the Declarative DSL compiler (`pipeline { ... }`), Groovy executor, and stage runtime engine. | **Mandatory** (Solves `NoSuchMethodError: pipeline`) |
| **Git** | `git` | Allows Jenkins to authenticate, clone, and check out your SCM codebase repository. | **Mandatory** |
| **Credentials Binding** | `credentials-binding` | Provides the `withCredentials` block to inject AWS Access Keys securely into build stages. | **Mandatory** |
| **AnsiColor** | `ansicolor` | Formats and colorizes CLI outputs (like green/red `terraform plan` additions/deletions). | **Recommended** |
| **Pipeline Utility Steps** | `pipeline-utility-steps` | Provides helper commands for manipulating directories and files during execution. | **Recommended** |

---

## 🛠️ Post-Installation Verification

Once installed, restart your Jenkins instance and run the following script in the **Jenkins Script Console** (**Manage Jenkins** -> **Script Console**) to verify they are loaded:

```groovy
def plugins = Jenkins.instance.pluginManager.plugins
def required = ['workflow-aggregator', 'git', 'credentials-binding', 'ansicolor']

println "Checking Required Plugins Status:"
required.each { id ->
    def p = plugins.find { it.shortName == id }
    if (p && p.isActive()) {
        println "✅ ${id} (version: ${p.version}) is active."
    } else {
        println "❌ ${id} is NOT installed or active!"
    }
}
```
