# Markdown file 2: Why does the SafeERC20 program exist and when should it be used?

SafeERC20 program exists to address inconsistencies in how different contracts implement the ERC-20 standard. Despite the existence of this standard, not all contracts fully comply with its requirements. 

Unsure why: 
- maybe erc20 was so early that full interface definitions were not achieved (i.e. defining return values wasn't scoped)
- maybe there is no way to ensure a standard is truly erc20 (like 777's use of registries) without introducing a level of undesired centralization that may not fully capture all aspects of compliance.